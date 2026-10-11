"""Shared, deterministic transforms and world-scale previews for authored PNGs."""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MANIFESTS = [f'tool/sprite_assets/manifests/hero/{name}.json' for name in (
    'seated_v1', 'sit_down_v1', 'sharpen_v1', 'walk_v2', 'attack_v1',
    'death_v1', 'stand_up_v1',
)]


def run(args, binary=False):
    result = subprocess.run([str(arg) for arg in args], check=True, capture_output=True)
    return result.stdout if binary else result.stdout.decode()


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def image_info(path):
    return json.loads(run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,pix_fmt', '-of', 'json', path]))['streams'][0]


def pixels(path):
    return run(['ffmpeg', '-v', 'error', '-i', path, '-frames:v', '1',
        '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)


def rooted(root, relative):
    path = Path(relative)
    resolved = (root / path).resolve()
    if path.is_absolute() or not resolved.is_relative_to(root.resolve()):
        raise ValueError(f'Path must stay within the asset root: {relative}')
    return resolved


def load_manifest(path, root=ROOT):
    """Resolve a small packing recipe and validate it before writing anything."""
    path, root = Path(path).resolve(), root.resolve()
    folder = path.parent.relative_to(root)
    data = json.loads(path.read_text())
    size = data['size']
    if type(size) is not int or size <= 0:
        raise ValueError('Invalid frame canvas')
    data['_folder'] = data.get('previewGroup', str(folder))
    data['_frames'] = []
    output = rooted(root, data['output'])
    atlas = 'frames' in data
    entries = data['frames'] if atlas else [data]
    if not entries:
        raise ValueError('Empty frame sequence')
    for index, entry in enumerate(entries):
        frame = dict(entry)
        frame['output'] = (str(Path(data.get('framesDirectory', str(folder / 'frames')))
            / f'{output.stem}_{index:02d}.png') if atlas else data['output'])
        rooted(root, frame['output'])
        if 'copy' in frame:
            frame['copy'] = str(folder / frame['copy'])
            info = image_info(rooted(root, frame['copy']))
            if [info['width'], info['height'], info['pix_fmt']] != [size, size, 'rgba']:
                raise ValueError('Invalid shared pose canvas')
        else:
            frame['source'] = str(folder / frame.get('source', data['source']))
            info = image_info(rooted(root, frame['source']))
            if info['pix_fmt'] != 'rgba':
                raise ValueError('Source must be RGBA')
            frame['crop'] = frame.get('crop', [0, 0, info['width'], info['height']])
            rect = frame['crop']
            if len(rect) != 4 or any(type(v) is not int for v in rect):
                raise ValueError('Invalid source rectangle')
            x, y, w, h = rect
            if min(x, y) < 0 or min(w, h) <= 0 or x+w > info['width'] or y+h > info['height']:
                raise ValueError('Source rectangle exceeds selected PNG')
            frame['_crop'] = 'crop' in entry
            # A different source (the attack guard) has its own scale/canvas.
            canvas = entry.get('sourceCanvas')
            if canvas is None and (not atlas or 'source' not in entry):
                canvas = data.get('sourceCanvas')
            if canvas is not None and (type(canvas) is not int or canvas <= 0):
                raise ValueError('Invalid source canvas')
            frame['sourceCanvas'] = canvas
            frame['scale'] = entry.get('scale', size / canvas if canvas else data.get('scale', 1))
            frame['offset'] = entry.get('offset', [0, 0])
            if not math.isfinite(frame['scale']) or frame['scale'] <= 0:
                raise ValueError('Invalid source scale')
            if len(frame['offset']) != 2 or any(type(v) is not int for v in frame['offset']):
                raise ValueError('Invalid whole-frame translation')
            frame_filter(data, frame)
        data['_frames'].append(frame)
    data['_atlas'] = data['output'] if atlas else None
    for target in [data.get('_atlas'), *data.get('copies', []), *data.get('exportFrames', {}).values()]:
        if target:
            rooted(root, target)
    for index in data.get('exportFrames', {}):
        if not index.isdigit() or int(index) >= len(entries):
            raise ValueError('Invalid exported frame index')
    return data


def frame_filter(data, frame):
    x, y, w, h = frame['crop']
    factor, canvas = frame['scale'], frame['sourceCanvas']
    left, top = frame['offset']
    size = data['size']
    crop = f'crop={w}:{h}:{x}:{y},format=rgba,' if frame['_crop'] else ''
    if canvas:
        if min(left, top) < 0 or left+w > canvas or top+h > canvas:
            raise ValueError('Translation exceeds common source canvas')
        return crop + f'pad={canvas}:{canvas}:{left}:{top}:color=black@0,scale={size}:{size}:flags=lanczos,format=rgba'
    sw, sh = round(w*factor), round(h*factor)
    if min(left, top) >= 0:
        if min(sw, sh) <= 0 or left+sw > size or top+sh > size:
            raise ValueError('Translation exceeds output canvas')
        return crop + f'scale={sw}:{sh}:flags=lanczos,pad={size}:{size}:{left}:{top}:color=black@0,format=rgba'
    # Preserve the authored guard's whole-image resize and upward translation.
    if [sw, sh] != [size, size] or left > 0 or top > 0:
        raise ValueError('Invalid scale/shift transform')
    return crop + f'scale={sw}:{sh}:flags=lanczos,format=rgba,pad={sw-left}:{sh-top}:0:0:color=black@0,crop={size}:{size}:{-left}:{-top}'


def render_frame(data, frame, root, output, shared_root=None):
    output.parent.mkdir(parents=True, exist_ok=True)
    if 'copy' in frame:
        shutil.copyfile(read_output(root, shared_root or root, frame['copy']), output)
        return
    run(['ffmpeg', '-v', 'error', '-y', '-i', rooted(root, frame['source']),
        '-vf', frame_filter(data, frame), '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', output])


def gif(output, frames, durations):
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sprite-gif-') as temp:
        concat = Path(temp) / 'sequence.ffconcat'
        # ffconcat quotes are its own syntax; never execute asset paths as code.
        def quote(path):
            return str(path.resolve()).replace("'", "'\\''")
        concat.write_text('ffconcat version 1.0\n' + ''.join(
            f"file '{quote(path)}'\noption framerate 100\nduration {duration}\n"
            for path, duration in zip(frames, durations)
        ) + f"file '{quote(frames[-1])}'\n")
        run(['ffmpeg', '-v', 'error', '-y', '-safe', '0', '-i', concat,
            '-filter_complex', '[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];'
                '[b][p]paletteuse=alpha_threshold=128',
            '-fps_mode', 'vfr', '-frames:v', str(len(frames)),
            '-final_delay', str(round(durations[-1]*100)), '-loop', '0', output])


def read_output(root, output_root, relative):
    path = rooted(output_root, relative)
    return path if path.exists() else rooted(root, relative)


def preview_filters(size, rig, preview):
    ref = preview['rig']
    # Scale the WHOLE frame using world units and anchor. No silhouette bbox fit.
    ratio = (rig['worldUnitsPerPixel'] * rig.get('scaleMultiplier', 1)
        / (ref['worldUnitsPerPixel'] * ref.get('scaleMultiplier', 1)))
    sw, sh = [round(n*ratio) for n in size]
    cw, ch = preview['canvas']
    x = round(cw*ref['anchor'][0] - sw*rig['anchor'][0])
    y = round(ch*ref['anchor'][1] - sh*rig['anchor'][1])
    if min(x, y) >= 0 and x+sw <= cw and y+sh <= ch:
        return f'scale={sw}:{sh}:flags=lanczos,pad={cw}:{ch}:{x}:{y}:color=black@0,format=rgba'
    # Full frame canvases can extend beyond the viewport because anchors differ.
    # Preserve the exact world transform, crop only to the shared viewport, and
    # let the preview margin check reject clipping of actual character pixels.
    ox, oy = min(0, x), min(0, y)
    pw, ph = max(cw, x+sw)-ox, max(ch, y+sh)-oy
    return (f'scale={sw}:{sh}:flags=lanczos,pad={pw}:{ph}:{x-ox}:{y-oy}:color=black@0,'
        f'crop={cw}:{ch}:{-ox}:{-oy},format=rgba')


@lru_cache(maxsize=1)
def runtime_previews():
    return json.loads(run(['dart', str(ROOT / 'tool/sprite_assets/export_animation_previews.dart')]))


def preview_data(folder=None):
    return {'previews': [p for p in runtime_previews() if folder is None or p['group'] == folder]}


def build_previews(data, root, output_root, frame_root=None):
    with tempfile.TemporaryDirectory(prefix='sprite-preview-') as temp:
        for preview in data.get('previews', []):
            frames, durations = [], []
            for index, step in enumerate(preview['sequence']):
                source = read_output(root, frame_root or output_root, step['asset'])
                dest = Path(temp) / f'{index:03d}.png'
                x, y, w, h = step['crop']
                filters = f'crop={w}:{h}:{x}:{y},format=rgba,' + preview_filters([w, h], step['rig'], preview)
                run(['ffmpeg', '-v', 'error', '-y', '-i', source, '-vf', filters,
                    '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', dest])
                alpha = pixels(dest)[3::4]
                cw, ch = preview['canvas']
                if any(alpha[:cw]) or any(alpha[-cw:]) or any(alpha[::cw]) or any(alpha[cw-1::cw]):
                    raise ValueError('World-scale viewport clips character pixels; enlarge the preview canvas')
                frames.append(dest)
                durations.append(step['duration'])
            gif(rooted(output_root, preview['output']), frames, durations)
            if preview.get('contactSheet'):
                output = rooted(output_root, preview['contactSheet'])
                output.parent.mkdir(parents=True, exist_ok=True)
                columns = 4
                rows = math.ceil(len(frames)/columns)
                run(['ffmpeg', '-v', 'error', '-y', '-framerate', '8', '-i', Path(temp)/'%03d.png',
                    '-vf', f'tile={columns}x{rows}:nb_frames={len(frames)}:padding=0:margin=0',
                    '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', output])


def build_manifest(path, root=ROOT, output_root=None, previews=True):
    output_root = output_root or root
    data = load_manifest(path, root)
    for frame in data['_frames']:
        render_frame(data, frame, root, rooted(output_root, frame['output']), shared_root=output_root)
    atlas = data['_atlas']
    if atlas:
        output = rooted(output_root, atlas)
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='sprite-atlas-') as temp:
            for index, frame in enumerate(data['_frames']):
                shutil.copyfile(rooted(output_root, frame['output']), Path(temp)/f'{index:03d}.png')
            count = len(data['_frames'])
            run(['ffmpeg', '-v', 'error', '-y', '-framerate', '8', '-i', Path(temp)/'%03d.png',
                '-vf', f'tile={count}x1:nb_frames={count}:padding=0:margin=0',
                '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', output])
    for target in data.get('copies', []):
        dest = rooted(output_root, target)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(rooted(output_root, data['output']), dest)
    for index, target in data.get('exportFrames', {}).items():
        dest = rooted(output_root, target)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(rooted(output_root, data['_frames'][int(index)]['output']), dest)
    if previews:
        build_previews(preview_data(data['_folder']), root, output_root)
    return data


def selected_manifests(names):
    if not names:
        return [ROOT / name for name in MANIFESTS]
    return [ROOT / name if not Path(name).is_absolute() else Path(name) for name in names]
