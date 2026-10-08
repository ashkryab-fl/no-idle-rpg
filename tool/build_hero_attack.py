#!/usr/bin/env python3
"""Package the four generated attack poses on a common canvas.

Run from the repository root: python3 tool/build_hero_attack.py
Pixel operations use ffmpeg, following the existing walk asset workflow.
Also installs the runtime attack sheet and its first frame as the combat guard.
"""

import json
import shutil
from pathlib import Path

from build_hero_walk import inspect, run


ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / 'art/hero/attack_v1'
RUNTIME = ROOT / 'assets/characters/hero'
SIZE = 512
CANVAS = 800
# Image generation does not guarantee exact grid boundaries. These source
# rectangles isolate the selected poses; origins align the pelvis and boots.
# All frames use one common scale, never independent silhouette fitting.
LAYOUT = [
    ((102, 199, 421, 450), (-81, -59)),
    ((650, 153, 420, 496), (469, -58)),
    ((99, 688, 565, 464), (-105, 433)),
    ((678, 772, 576, 424), (470, 437)),
]


def main():
    source = inspect(ART / 'source-sheet.png')
    width, height = source['width'], source['height']
    if (width, height) != (1254, 1254):
        raise ValueError('Expected the selected 1254x1254 generated source')
    frames = ART / 'frames'
    frames.mkdir(parents=True, exist_ok=True)
    poses = ['ready', 'backswing', 'strike', 'follow-through']
    metadata = []
    for index, pose in enumerate(poses):
        path = frames / f'attack_{index:02d}.png'
        (x, y, w, h), (origin_x, origin_y) = LAYOUT[index]
        ready_source = ART / 'source-ready.png'
        if index == 0 and ready_source.exists():
            inspect(ready_source)
            input_path = ready_source
            filters = (f'scale={SIZE}:{SIZE}:flags=lanczos,format=rgba,'
                       f'pad={SIZE}:{SIZE+8}:0:0:color=black@0,'
                       f'crop={SIZE}:{SIZE}:0:8')
            source_metadata = {'sourceFrame': str(ready_source.relative_to(ROOT)),
                               'verticalShiftPixels': -8}
        else:
            input_path = source['path']
            filters = (f'crop={w}:{h}:{x}:{y},format=rgba,'
                       f'pad={CANVAS}:{CANVAS}:{x-origin_x}:{y-origin_y}:color=black@0,'
                       f'scale={SIZE}:{SIZE}:flags=lanczos,format=rgba')
            source_metadata = {'sourceRect': [x, y, w, h],
                               'canvasOrigin': [origin_x, origin_y]}
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(input_path),
             '-vf', filters,
             '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(path)])
        item = inspect(path)
        raw = run(['ffmpeg', '-v', 'error', '-i', str(path), '-frames:v', '1',
                   '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
        alpha = raw[3::4]
        if any(alpha[:SIZE]) or any(alpha[-SIZE:]) or any(alpha[::SIZE]) or any(alpha[SIZE-1::SIZE]):
            raise ValueError(f'Frame {index}: artwork touches a cell border')
        metadata.append({'index': index, 'pose': pose,
                         **source_metadata,
                         'bounds': item['bbox']})
    sequence = str(frames / 'attack_%02d.png')
    sheet = ART / 'attack.png'
    run(['ffmpeg', '-v', 'error', '-y', '-framerate', '8', '-i', sequence,
         '-vf', 'tile=4x1:nb_frames=4:padding=0:margin=0',
         '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(sheet)])
    raw_sheet = run(['ffmpeg', '-v', 'error', '-i', str(sheet), '-frames:v', '1',
                     '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
    for index in range(4):
        raw = run(['ffmpeg', '-v', 'error', '-i', str(frames / f'attack_{index:02d}.png'),
                   '-frames:v', '1', '-pix_fmt', 'rgba', '-f', 'rawvideo', '-'], binary=True)
        for y in range(SIZE):
            start = (y * SIZE * 4 + index * SIZE) * 4
            if raw[y*SIZE*4:(y+1)*SIZE*4] != raw_sheet[start:start+SIZE*4]:
                raise ValueError(f'Sheet cell {index} differs from its frame')
    # The first pose is held between repeated attacks in the review preview.
    durations = [.40, .15, .10, .15]
    concat = ART / 'preview.ffconcat'
    concat.write_text('ffconcat version 1.0\n' + ''.join(
        f"file 'frames/attack_{index:02d}.png'\noption framerate 100\nduration {duration}\n"
        for index, duration in enumerate(durations)
    ) + "file 'frames/attack_03.png'\n")
    run(['ffmpeg', '-v', 'error', '-y', '-safe', '0', '-i', str(concat),
         '-filter_complex', '[0:v]split[a][b];[a]palettegen=reserve_transparent=1[p];'
                            '[b][p]paletteuse=alpha_threshold=128',
         '-fps_mode', 'vfr', '-frames:v', '4', '-final_delay', '15',
         '-loop', '0', str(ART / 'attack-preview.gif')])
    concat.unlink()
    RUNTIME.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(sheet, RUNTIME / 'attack.png')
    shutil.copyfile(frames / 'attack_00.png', RUNTIME / 'ready.png')
    manifest = {'sheet': str(sheet.relative_to(ROOT)), 'frameSize': [SIZE, SIZE],
                'frames': 4, 'order': 'left-to-right', 'alpha': True,
                'previewDurationsSeconds': durations,
                'sourceSheet': str(source['path'].relative_to(ROOT)),
                'commonCanvas': [CANVAS, CANVAS],
                'anchor': [.58, .875], 'frameDetails': metadata,
                'gameplayRegistered': True,
                'runtime': {'attackSheet': 'assets/characters/hero/attack.png',
                            'guardFrame': 'assets/characters/hero/ready.png',
                            'attackStepTime': .15, 'damageEventTime': .35,
                            'scale': .25}}
    (ART / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))
    print('Verified four RGBA frames, transparent borders, and exact sheet cells.')


if __name__ == '__main__':
    main()
