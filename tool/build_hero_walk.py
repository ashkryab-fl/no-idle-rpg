#!/usr/bin/env python3
"""Normalize individual walk PNGs and assemble the sheet using ffmpeg only.

Python reads alpha metadata and orchestrates ffmpeg; it never paints pixels.
Run from the repository root: python3 tool/build_hero_walk.py
"""

import json
import argparse
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'art/hero/walk_v2/source_frames'
FRAMES = ROOT / 'assets/characters/hero/walk_frames'
SHEET = ROOT / 'assets/characters/hero/walk.png'
PREVIEW = ROOT / 'art/hero/walk_v2/walk-preview.gif'
SIZE, FPS, COUNT = 512, 8, 10


def extract_sources():
    reference = SOURCE.parent / 'reference.png'
    metadata = inspect(reference)
    if (metadata['width'], metadata['height']) != (1280, 1280):
        raise ValueError('Expected the supplied 5x5 sheet with 256x256 cells')
    SOURCE.mkdir(parents=True, exist_ok=True)
    for index in range(COUNT):
        x, y = (index % 5) * 256, (index // 5) * 256
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(reference),
             '-vf', f'crop=256:256:{x}:{y},format=rgba', '-frames:v', '1',
             '-pix_fmt', 'rgba', '-update', '1',
             str(SOURCE / f'walk_{index:02d}.png')])


def run(args, binary=False):
    result = subprocess.run(args, check=True, capture_output=True)
    return result.stdout if binary else result.stdout.decode()


def inspect(path):
    probe = json.loads(run([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,pix_fmt', '-of', 'json', str(path),
    ]))['streams'][0]
    width, height = probe['width'], probe['height']
    if probe['pix_fmt'] != 'rgba':
        raise ValueError(f'{path.name}: expected RGBA, got {probe["pix_fmt"]}')
    alpha = run([
        'ffmpeg', '-v', 'error', '-i', str(path), '-vf', 'alphaextract',
        '-frames:v', '1', '-pix_fmt', 'gray', '-f', 'rawvideo', '-',
    ], binary=True)
    if len(alpha) != width * height or 0 not in alpha or 255 not in alpha:
        raise ValueError(f'{path.name}: missing valid transparent/opaque alpha')
    left, top, right, bottom = width, height, 0, 0
    for index, value in enumerate(alpha):
        if value < 16:
            continue
        x, y = index % width, index // width
        left, top = min(left, x), min(top, y)
        right, bottom = max(right, x + 1), max(bottom, y + 1)
    if right <= left or bottom <= top:
        raise ValueError(f'{path.name}: empty character')
    return {'path': path, 'width': width, 'height': height,
            'bbox': [left, top, right, bottom]}


def verify():
    sheet = inspect(SHEET)
    if (sheet['width'], sheet['height']) != (SIZE * COUNT, SIZE):
        raise ValueError('Unexpected sheet dimensions')
    raw_sheet = run(['ffmpeg', '-v', 'error', '-i', str(SHEET), '-frames:v', '1',
                     '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
    for index in range(COUNT):
        path = FRAMES / f'walk_{index:02d}.png'
        frame = inspect(path)
        if (frame['width'], frame['height']) != (SIZE, SIZE):
            raise ValueError(f'Frame {index}: unexpected size')
        raw = run(['ffmpeg', '-v', 'error', '-i', str(path), '-frames:v', '1',
                   '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
        alpha = raw[3::4]
        solid_pixels = sum(value >= 250 for value in alpha)
        if alpha.count(0) < SIZE * SIZE / 4 or solid_pixels < SIZE * SIZE / 20:
            raise ValueError(f'Frame {index}: missing transparent background or opaque character')
        for y in range(SIZE):
            start = (y * SIZE * COUNT + index * SIZE) * 4
            if raw[y * SIZE * 4:(y + 1) * SIZE * 4] != raw_sheet[start:start + SIZE * 4]:
                raise ValueError(f'Frame {index}: sheet cell does not match separate PNG')
            if alpha[y * SIZE] or alpha[y * SIZE + SIZE - 1]:
                raise ValueError(f'Frame {index}: artwork touches horizontal border')
        if any(alpha[:SIZE]) or any(alpha[-SIZE:]):
            raise ValueError(f'Frame {index}: artwork touches vertical border')
    print(f'Verified: {COUNT} RGBA frames, transparent margins, exact PNG-to-sheet cells.')


def main():
    extract_sources()
    inputs = [inspect(SOURCE / f'walk_{index:02d}.png') for index in range(COUNT)]
    # The supplied sheet already has a common rig/canvas. Scale every complete
    # cell by exactly 2x; per-frame cropping or fitting would change the motion.
    FRAMES.mkdir(parents=True, exist_ok=True)
    manifest_frames = []
    for index, item in enumerate(inputs):
        if (item['width'], item['height']) != (256, 256):
            raise ValueError(f'Frame {index}: expected original 256x256 cell')
        destination = FRAMES / f'walk_{index:02d}.png'
        filters = (
            f'format=rgba,scale={SIZE}:{SIZE}:flags=lanczos,format=rgba'
        )
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(item['path']),
             '-vf', filters, '-frames:v', '1', '-pix_fmt', 'rgba',
             '-update', '1', str(destination)])
        manifest_frames.append({'index': index, 'sourceSize': [item['width'], item['height']],
                                'sourceBounds': item['bbox'],
                                'sourceCell': [index % 5, index // 5],
                                'placedBounds': inspect(destination)['bbox']})
    sequence = str(FRAMES / 'walk_%02d.png')
    run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(FPS), '-start_number', '0',
         '-i', sequence, '-vf', f'tile={COUNT}x1:nb_frames={COUNT}:padding=0:margin=0',
         '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(SHEET)])
    # GIF is a preview; the gameplay PNG keeps full RGBA transparency.
    run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(FPS), '-start_number', '0',
         '-i', sequence, '-filter_complex',
         '[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=alpha_threshold=128',
         '-loop', '0', str(PREVIEW)])
    manifest = {'sheet': str(SHEET.relative_to(ROOT)), 'frameSize': [SIZE, SIZE],
                'frames': COUNT, 'fps': FPS, 'stepTime': 1 / FPS, 'loop': True,
                'anchor': [.62, .875], 'scale': .20,
                'upscale': {'factor': 2, 'filter': 'lanczos'},
                'sourceSheet': str((SOURCE.parent / 'reference.png').relative_to(ROOT)),
                'frameTransforms': manifest_frames}
    (SOURCE.parent / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    verify()
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify existing PNGs without rebuilding')
    if parser.parse_args().check:
        verify()
    else:
        main()
