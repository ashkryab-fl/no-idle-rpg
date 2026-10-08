#!/usr/bin/env python3
"""Pack seated reference, sit-down entry and sharpening loop with ffmpeg.

No artwork is painted here. Generated poses are extracted, translated and
scaled on a shared transparent canvas. The common transition frame is copied
exactly, not regenerated. Run with --verify to check existing packaged assets.
"""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from build_hero_walk import inspect, run


ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / 'art/hero'
RUNTIME = ROOT / 'assets/characters/hero'
SIZE = 512
SIT = ART / 'sit_down_v1'
SHARPEN = ART / 'sharpen_v1'
SEATED = ART / 'seated_v1'
# Whole-pose transforms; one common scale per generated sheet. Body centers
# and ground contact stay aligned as the standing figure becomes shorter.
SIT_LAYOUT = [
    ((0, 0, 660, 672), (100, 149)),
    ((660, 0, 594, 672), (127, 150)),
    ((0, 672, 638, 582), (108, 192)),
]
SIT_SCALE = .45
SHARPEN_SCALE = .49
# Filled from the selected source's fixed grid and body/ground positions.
SHARPEN_LAYOUT = [
    ((627, 0, 627, 627), (107, 156)),
    ((0, 627, 627, 627), (85, 182)),
    ((627, 627, 627, 627), (107, 181)),
]
SHARPEN_ORDER = [0, 1, 2, 1, 3]
SHARPEN_STEP = .225  # Previous FPS * 0.8: 0.18 / 0.8 seconds per frame.


def extract(source, rect, scale, offset, output):
    x, y, w, h = rect
    left, top = offset
    filters = (
        f'crop={w}:{h}:{x}:{y},format=rgba,'
        f'scale={round(w*scale)}:{round(h*scale)}:flags=lanczos,'
        f'pad={SIZE}:{SIZE}:{left}:{top}:color=black@0,format=rgba'
    )
    run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-vf', filters,
         '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(output)])


def pack(folder, name, count, step):
    run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(1 / step),
         '-i', str(folder / 'frames' / f'{name}_%02d.png'),
         '-vf', f'tile={count}x1:nb_frames={count}:padding=0:margin=0',
         '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1',
         str(folder / f'{name}.png')])
    shutil.copyfile(folder / f'{name}.png', RUNTIME / f'{name}.png')


def gif(folder, name, frames, durations):
    concat = folder / f'{name}.ffconcat'
    concat.write_text('ffconcat version 1.0\n' + ''.join(
        f"file '{path.resolve()}'\noption framerate 100\nduration {duration}\n"
        for path, duration in zip(frames, durations)
    ) + f"file '{frames[-1].resolve()}'\n")
    try:
        run(['ffmpeg', '-v', 'error', '-y', '-safe', '0', '-i', str(concat),
             '-filter_complex', '[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];'
                                '[b][p]paletteuse=alpha_threshold=128',
             '-fps_mode', 'vfr', '-frames:v', str(len(frames)),
             '-final_delay', str(round(durations[-1] * 100)), '-loop', '0',
             str(folder / f'{name}-preview.gif')])
    finally:
        concat.unlink(missing_ok=True)


def pixels(path):
    return run(['ffmpeg', '-v', 'error', '-i', str(path), '-frames:v', '1',
                '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)


def verify():
    reference = SEATED / 'reference.png'
    copies = [SIT / 'frames/sit_down_03.png', SHARPEN / 'frames/sharpen_00.png',
              RUNTIME / 'seated.png']
    if any(path.read_bytes() != reference.read_bytes() for path in copies):
        raise ValueError('Shared seated reference must be copied byte-for-byte')
    for folder, name, count in [(SIT, 'sit_down', 4), (SHARPEN, 'sharpen', 5)]:
        sheet = folder / f'{name}.png'
        info = inspect(sheet)
        if (info['width'], info['height']) != (SIZE * count, SIZE):
            raise ValueError(f'{name}: invalid sheet dimensions')
        if sheet.read_bytes() != (RUNTIME / f'{name}.png').read_bytes():
            raise ValueError(f'{name}: installed sheet differs')
        raw_sheet = pixels(sheet)
        for index in range(count):
            path = folder / 'frames' / f'{name}_{index:02d}.png'
            info = inspect(path)
            if (info['width'], info['height']) != (SIZE, SIZE):
                raise ValueError(f'{name}/{index}: invalid frame dimensions')
            raw = pixels(path)
            alpha = raw[3::4]
            if any(alpha[:SIZE]) or any(alpha[-SIZE:]) or any(alpha[::SIZE]) or any(alpha[SIZE-1::SIZE]):
                raise ValueError(f'{name}/{index}: artwork touches canvas border')
            for y in range(SIZE):
                start = (y * SIZE * count + index * SIZE) * 4
                if raw[y*SIZE*4:(y+1)*SIZE*4] != raw_sheet[start:start+SIZE*4]:
                    raise ValueError(f'{name}/{index}: sheet cell differs')
    print('Verified RGBA, transparent margins, exact sheet cells and identical seated seam.')


def main():
    for folder in [SIT, SHARPEN]:
        (folder / 'frames').mkdir(parents=True, exist_ok=True)
        source = inspect(folder / 'source-sheet.png')
        if (source['width'], source['height']) != (1254, 1254):
            raise ValueError(f'{folder.name}: unexpected source dimensions')
    # Select the neutral pose from the same rig as the moving hands. The earlier
    # single-pose study remains an identity reference, not a mismatched seam.
    source = SHARPEN / 'source-sheet.png'
    run(['ffmpeg', '-v', 'error', '-y', '-i', str(source),
         '-vf', 'crop=627:627:0:0,format=rgba', '-frames:v', '1',
         '-pix_fmt', 'rgba', '-update', '1', str(SEATED / 'source-reference.png')])
    extract(source, (0, 0, 627, 627), SHARPEN_SCALE, (85, 156),
            SEATED / 'reference.png')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SEATED / 'reference.png', RUNTIME / 'seated.png')
    for index, (rect, offset) in enumerate(SIT_LAYOUT):
        extract(SIT / 'source-sheet.png', rect, SIT_SCALE, offset,
                SIT / 'frames' / f'sit_down_{index:02d}.png')
    shutil.copyfile(SEATED / 'reference.png', SIT / 'frames/sit_down_03.png')
    for index, pose in enumerate(SHARPEN_ORDER):
        output = SHARPEN / 'frames' / f'sharpen_{index:02d}.png'
        if pose == 0:
            shutil.copyfile(SEATED / 'reference.png', output)
        else:
            rect, offset = SHARPEN_LAYOUT[pose - 1]
            extract(SHARPEN / 'source-sheet.png', rect, SHARPEN_SCALE, offset, output)
    (SHARPEN / 'frames/sharpen_05.png').unlink(missing_ok=True)
    pack(SIT, 'sit_down', 4, .3)
    pack(SHARPEN, 'sharpen', 5, SHARPEN_STEP)
    sit_frames = [SIT / 'frames' / f'sit_down_{index:02d}.png' for index in range(4)]
    loop_frames = [SHARPEN / 'frames' / f'sharpen_{index:02d}.png' for index in range(5)]
    gif(SIT, 'sit-down', sit_frames, [.3, .3, .3, .8])
    # The shared entry pose is shown once. Active frames keep the stone in hand
    # across cycle boundaries, so the tool does not blink away every second.
    gif(SHARPEN, 'sharpen', loop_frames[1:], [SHARPEN_STEP] * 4)
    gif(SIT, 'rest', sit_frames + loop_frames[:1] + loop_frames[1:] * 3,
        [.3, .3, .3, .8, SHARPEN_STEP] + [SHARPEN_STEP] * 12)
    manifest = {
        'frameSize': [SIZE, SIZE], 'alpha': True, 'anchor': [.5, .875], 'scale': .25,
        'seatedReference': str((SEATED / 'reference.png').relative_to(ROOT)),
        'seatedSourceReference': str((SEATED / 'source-reference.png').relative_to(ROOT)),
        'seatedReferenceSha256': hashlib.sha256((SEATED / 'reference.png').read_bytes()).hexdigest(),
        'sitDown': {'frames': 4, 'stepTime': .3, 'loop': False, 'endHold': .5,
                    'sourceScale': SIT_SCALE, 'layout': SIT_LAYOUT},
        'sharpen': {'frames': 5, 'stepTime': SHARPEN_STEP, 'loop': True,
                    'loopStartFrame': 1, 'loopDuration': .9,
                    'poseOrder': SHARPEN_ORDER, 'sourceScale': SHARPEN_SCALE,
                    'layout': SHARPEN_LAYOUT},
        'sharedFrames': ['sit_down:3', 'sharpen:0', 'seated:0'],
    }
    (SIT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    verify()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    if parser.parse_args().verify:
        verify()
    else:
        main()
