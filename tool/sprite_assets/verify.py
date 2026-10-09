#!/usr/bin/env python3
"""Verify reproducible PNGs, exact atlas cells, margins and shared poses."""
import argparse
from pathlib import Path
import tempfile

try:
    from .pipeline import ROOT, build_previews, image_info, load_manifest, pixels, preview_data, read_output, render_frame, rooted, selected_manifests
except ImportError:
    from pipeline import ROOT, build_previews, image_info, load_manifest, pixels, preview_data, read_output, render_frame, rooted, selected_manifests


def verify_previews(data, root=ROOT, output_root=None):
    output_root = output_root or root
    with tempfile.TemporaryDirectory(prefix='sprite-preview-verify-') as temp:
        generated = Path(temp)
        build_previews(data, root, generated, frame_root=output_root)
        for preview in data['previews']:
            info = image_info(rooted(output_root, preview['output']))
            if [info['width'], info['height']] != preview['canvas']:
                raise ValueError('World-scale preview canvas differs')
            for field in ['output', 'contactSheet']:
                if field in preview and rooted(output_root, preview[field]).read_bytes() != rooted(generated, preview[field]).read_bytes():
                    raise ValueError(f'World-scale sequence/rig/duration differs: {preview[field]}')


def verify_manifest(path, root=ROOT, output_root=None, rebuild=True, previews=False):
    output_root = output_root or root
    data = load_manifest(path, root)
    width = height = data['size']
    frames = data['_frames']
    atlas = data['_atlas']
    sheet = None
    if atlas:
        info = image_info(rooted(output_root, atlas))
        if [info['width'], info['height'], info['pix_fmt']] != [width*len(frames), height, 'rgba']:
            raise ValueError('Invalid RGBA atlas canvas')
        sheet = pixels(rooted(output_root, atlas))
    with tempfile.TemporaryDirectory(prefix='sprite-verify-') as temp:
        for index, frame in enumerate(frames):
            path = rooted(output_root, frame['output'])
            info = image_info(path)
            if [info['width'], info['height'], info['pix_fmt']] != [width, height, 'rgba']:
                raise ValueError(f'Invalid RGBA frame: {path}')
            raw = pixels(path)
            alpha = raw[3::4]
            if (alpha.count(0) < width*height*.25
                or sum(a >= 250 for a in alpha) < min(5000, width*height/8)):
                raise ValueError(f'Invalid transparent/solid pixels: {path}')
            if any(alpha[:width]) or any(alpha[-width:]) or any(alpha[::width]) or any(alpha[width-1::width]):
                raise ValueError(f'Artwork touches frame margin: {path}')
            if sheet:
                for y in range(height):
                    start = (y*width*len(frames) + index*width)*4
                    if raw[y*width*4:(y+1)*width*4] != sheet[start:start+width*4]:
                        raise ValueError(f'Atlas cell differs: {path}')
            if 'copy' in frame and path.read_bytes() != read_output(root, output_root, frame['copy']).read_bytes():
                raise ValueError(f'Shared pose differs: {path}')
            if rebuild:
                generated = Path(temp) / f'{index}.png'
                render_frame(data, frame, root, generated, shared_root=output_root)
                if generated.read_bytes() != path.read_bytes():
                    raise ValueError(f'Source rectangle/order/transform does not reproduce: {path}')
    for target in data.get('copies', []):
        if rooted(output_root, data['output']).read_bytes() != rooted(output_root, target).read_bytes():
            raise ValueError(f'Installed pose differs: {target}')
    for index, target in data.get('exportFrames', {}).items():
        if rooted(output_root, frames[int(index)]['output']).read_bytes() != rooted(output_root, target).read_bytes():
            raise ValueError(f'Exported frame differs: {target}')
    if previews:
        verify_previews(preview_data(data['_folder']), root, output_root)
    print(f'Verified {data["output"]}: source reproduction, RGBA cells, margins, shared poses.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifests', nargs='*')
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--previews', action='store_true')
    args = parser.parse_args()
    for path in selected_manifests(args.manifests):
        verify_manifest(path, output_root=args.output_root, previews=args.previews)
    if args.previews and not args.manifests:
        verify_previews(preview_data('art/hero/rest_variants_v1'), output_root=args.output_root)


if __name__ == '__main__':
    main()
