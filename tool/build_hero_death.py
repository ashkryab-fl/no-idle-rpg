#!/usr/bin/env python3
"""Pack the generated death poses using ffmpeg and install the runtime sheet.

Run from the repository root: python3 tool/build_hero_death.py
All frames use one common canvas/scale, aligned at the planted sword point.
"""

import json
import shutil
from pathlib import Path

from build_hero_walk import inspect, run


ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / 'art/hero/death_v1'
SIZE, CANVAS = 512, 940
# Selected source has uneven row spacing. Only whole-pose translation and a
# common resize are used; kneeling poses retain their shorter natural height.
LAYOUT = [
    ((0, 0, 627, 660), (-176, -186)),
    ((627, 0, 627, 660), (411, -184)),
    ((0, 660, 627, 594), (-148, 358)),
    ((627, 660, 627, 594), (455, 358)),
]
DURATIONS = [.4, .4, .4, 1.0]


def main():
    source = inspect(ART / 'source-sheet.png')
    if (source['width'], source['height']) != (1254, 1254):
        raise ValueError('Expected the selected 1254x1254 source')
    frames = ART / 'frames'
    frames.mkdir(parents=True, exist_ok=True)
    poses = ['plant-sword', 'bow-head', 'sink-to-knees', 'kneeling-defeat']
    metadata = []
    pixels = []
    for index, pose in enumerate(poses):
        (x, y, w, h), (origin_x, origin_y) = LAYOUT[index]
        path = frames / f'death_{index:02d}.png'
        filters = (f'crop={w}:{h}:{x}:{y},format=rgba,'
                   f'pad={CANVAS}:{CANVAS}:{x-origin_x}:{y-origin_y}:color=black@0,'
                   f'scale={SIZE}:{SIZE}:flags=lanczos,format=rgba')
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(source['path']),
             '-vf', filters, '-frames:v', '1', '-pix_fmt', 'rgba',
             '-update', '1', str(path)])
        item = inspect(path)
        raw = run(['ffmpeg', '-v', 'error', '-i', str(path), '-frames:v', '1',
                   '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
        alpha = raw[3::4]
        if any(alpha[:SIZE]) or any(alpha[-SIZE:]) or any(alpha[::SIZE]) or any(alpha[SIZE-1::SIZE]):
            raise ValueError(f'Frame {index}: artwork touches a cell border')
        pixels.append(raw)
        metadata.append({'index': index, 'pose': pose,
                         'sourceRect': [x, y, w, h],
                         'canvasOrigin': [origin_x, origin_y],
                         'bounds': item['bbox']})
    sheet = ART / 'death.png'
    run(['ffmpeg', '-v', 'error', '-y', '-framerate', '5/2',
         '-i', str(frames / 'death_%02d.png'),
         '-vf', 'tile=4x1:nb_frames=4:padding=0:margin=0',
         '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(sheet)])
    raw_sheet = run(['ffmpeg', '-v', 'error', '-i', str(sheet), '-frames:v', '1',
                     '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
    for index, raw in enumerate(pixels):
        for y in range(SIZE):
            start = (y * SIZE * 4 + index * SIZE) * 4
            if raw[y*SIZE*4:(y+1)*SIZE*4] != raw_sheet[start:start+SIZE*4]:
                raise ValueError(f'Sheet cell {index} differs from its PNG')
    concat = ART / 'preview.ffconcat'
    concat.write_text('ffconcat version 1.0\n' + ''.join(
        f"file 'frames/death_{index:02d}.png'\noption framerate 100\nduration {duration}\n"
        for index, duration in enumerate(DURATIONS)
    ) + "file 'frames/death_03.png'\n")
    run(['ffmpeg', '-v', 'error', '-y', '-safe', '0', '-i', str(concat),
         '-filter_complex', '[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];'
                            '[b][p]paletteuse=alpha_threshold=128',
         '-fps_mode', 'vfr', '-frames:v', '4', '-final_delay', '100',
         '-loop', '0', str(ART / 'death-preview.gif')])
    concat.unlink()
    runtime = ROOT / 'assets/characters/hero/death.png'
    runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(sheet, runtime)
    manifest = {'sheet': str(runtime.relative_to(ROOT)), 'frameSize': [SIZE, SIZE],
                'frames': 4, 'loop': False, 'stepTime': .4,
                'visibleFrameDurations': DURATIONS, 'totalSeconds': sum(DURATIONS),
                'respawnHoldSeconds': .6, 'anchor': [.58, .875], 'scale': .25,
                'sourceSheet': str(source['path'].relative_to(ROOT)),
                'commonCanvas': [CANVAS, CANVAS], 'frameDetails': metadata}
    (ART / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))
    print('Verified four RGBA frames, transparent borders and exact sheet cells.')


if __name__ == '__main__':
    main()
