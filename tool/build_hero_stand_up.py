#!/usr/bin/env python3
"""Pack six generated stand-up poses and preview the real seated/walk seams.

ffmpeg performs only extraction, uniform scaling, translation and assembly.
The existing seated and walking artwork is never modified.
"""

import argparse
import hashlib
import json
import shutil

from build_hero_rest import ART, RUNTIME, SIZE, extract, gif, pack, pixels
from build_hero_walk import run


FOLDER = ART / 'stand_up_v1'
COUNT, STEP, SOURCE_SCALE = 6, .25, .59
# The row gutter is at y=506. The first bottom-row ponytail extends slightly
# past its nominal x=512 cell; the wider crop preserves it without its neighbor.
# Common scale; translations follow the body's pivot and planted foot.
LAYOUT = [
    ((0, 0, 512, 506), (73, 154)),
    ((512, 0, 512, 506), (73, 152)),
    ((1024, 0, 512, 506), (66, 151)),
    ((0, 506, 535, 518), (24, 157)),
    ((535, 506, 489, 518), (29, 157)),
    ((1024, 506, 512, 518), (15, 157)),
]


def dimensions(path):
    return json.loads(run([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,pix_fmt', '-of', 'json', str(path),
    ]))['streams'][0]


def verify():
    sheet = FOLDER / 'stand_up.png'
    info = dimensions(sheet)
    if (info['width'], info['height'], info['pix_fmt']) != (SIZE * COUNT, SIZE, 'rgba'):
        raise ValueError('Expected six horizontal 512x512 RGBA cells')
    if sheet.read_bytes() != (RUNTIME / 'stand_up.png').read_bytes():
        raise ValueError('Installed stand-up differs from packaged sheet')
    seated = ART / 'seated_v1/reference.png'
    if seated.read_bytes() != (RUNTIME / 'seated.png').read_bytes():
        raise ValueError('The shared neutral seated pose must stay identical')
    raw_sheet = pixels(sheet)
    for index in range(COUNT):
        path = FOLDER / 'frames' / f'stand_up_{index:02d}.png'
        info = dimensions(path)
        if (info['width'], info['height'], info['pix_fmt']) != (SIZE, SIZE, 'rgba'):
            raise ValueError(f'Frame {index}: invalid dimensions/format')
        raw = pixels(path)
        alpha = raw[3::4]
        if alpha.count(0) < SIZE * SIZE / 2 or sum(a >= 250 for a in alpha) < 5000:
            raise ValueError(f'Frame {index}: invalid transparency/solid character')
        if any(alpha[:SIZE]) or any(alpha[-SIZE:]) or any(alpha[::SIZE]) or any(alpha[SIZE-1::SIZE]):
            raise ValueError(f'Frame {index}: artwork touches canvas border')
        for y in range(SIZE):
            start = (y * SIZE * COUNT + index * SIZE) * 4
            if raw[y*SIZE*4:(y+1)*SIZE*4] != raw_sheet[start:start+SIZE*4]:
                raise ValueError(f'Frame {index}: sheet cell differs')
    manifest = json.loads((FOLDER / 'manifest.json').read_text())
    source = FOLDER / manifest['source']
    if manifest['sourceSha256'] != hashlib.sha256(source.read_bytes()).hexdigest():
        raise ValueError('Corrected source changed; rebuild the packaged animation')
    for key, path in [
        ('seatedReferenceSha256', seated),
        ('walkEntrySha256', ART / 'walk_v2/source_frames/walk_00.png'),
    ]:
        if manifest[key] != hashlib.sha256(path.read_bytes()).hexdigest():
            raise ValueError(f'{key}: transition reference changed; review the seam')
    print('Verified six RGBA frames, margins, exact sheet cells and unchanged seated/walk references.')


def main():
    source = FOLDER / 'source-corrected.png'
    info = dimensions(source)
    if (info['width'], info['height'], info['pix_fmt']) != (1536, 1024, 'rgba'):
        raise ValueError('Unexpected generated source dimensions/format')
    (FOLDER / 'frames').mkdir(parents=True, exist_ok=True)
    (FOLDER / 'source_frames').mkdir(parents=True, exist_ok=True)
    for index, (rect, offset) in enumerate(LAYOUT):
        x, y, w, h = rect
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(source),
             '-vf', f'crop={w}:{h}:{x}:{y},format=rgba', '-frames:v', '1',
             '-pix_fmt', 'rgba', '-update', '1',
             str(FOLDER / 'source_frames' / f'stand_up_{index:02d}.png')])
        extract(source, rect, SOURCE_SCALE, offset,
                FOLDER / 'frames' / f'stand_up_{index:02d}.png')
    pack(FOLDER, 'stand_up', COUNT, STEP)
    run(['ffmpeg', '-v', 'error', '-y', '-i', str(source),
         '-f', 'lavfi', '-i', 'color=c=0x223039:s=1536x1024',
         '-filter_complex', '[1:v][0:v]overlay,format=rgb24[out]',
         '-map', '[out]', '-frames:v', '1', '-update', '1',
         str(FOLDER / 'alpha-review.png')])
    frames = [FOLDER / 'frames' / f'stand_up_{i:02d}.png' for i in range(COUNT)]
    gif(FOLDER, 'stand-up', frames, [STEP] * COUNT)
    preview = FOLDER / '.preview_frames'
    preview.mkdir(exist_ok=True)
    try:
        # Put walk on the seated rig's canvas for a truthful world-size preview:
        # walk scale .20 / seated scale (.25 * 1.05) = 16/21.
        # Its anchor .62 becomes x=.5; both use ground anchor y=.875.
        walks = []
        for index in range(10):
            path = preview / f'walk_{index:02d}.png'
            run(['ffmpeg', '-v', 'error', '-y', '-i',
                 str(RUNTIME / 'walk_frames' / f'walk_{index:02d}.png'),
                 '-vf', 'format=rgba,scale=390:390:flags=lanczos,'
                        'pad=512:512:14:107:color=black@0,format=rgba',
                 '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', str(path)])
            walks.append(path)
        seated = ART / 'seated_v1/reference.png'
        gif(FOLDER, 'wake-to-walk',
            [ART / 'sharpen_v1/frames/sharpen_04.png', seated] + frames + walks,
            [.225, .3] + [STEP] * COUNT + [.125] * 10)
        for index, path in enumerate([seated] + frames + walks[:1]):
            shutil.copyfile(path, preview / f'contact_{index:02d}.png')
        run(['ffmpeg', '-v', 'error', '-y', '-i', str(preview / 'contact_%02d.png'),
             '-f', 'lavfi', '-i', 'color=c=0x223039:s=2048x1024',
             '-filter_complex', '[0:v]tile=4x2:nb_frames=8[t];[1:v][t]overlay,format=rgb24[out]',
             '-map', '[out]', '-frames:v', '1', '-update', '1',
             str(FOLDER / 'transition-contact.png')])
    finally:
        shutil.rmtree(preview)
    manifest = {
        'sheet': 'assets/characters/hero/stand_up.png',
        'frames': COUNT, 'frameSize': [SIZE, SIZE], 'stepTime': STEP, 'loop': False,
        'anchor': [.5, .875], 'scale': .25, 'scaleMultiplier': 1.05,
        'sourceScale': SOURCE_SCALE, 'layout': LAYOUT,
        'neutralHold': {'animationId': 'hero.seated', 'duration': .3,
                        'includedInStandUpFrames': False},
        'seatedReferenceSha256': hashlib.sha256((ART / 'seated_v1/reference.png').read_bytes()).hexdigest(),
        'walkEntrySha256': hashlib.sha256((ART / 'walk_v2/source_frames/walk_00.png').read_bytes()).hexdigest(),
        'followingAnimation': 'hero.walk', 'followingFrame': 0,
        'previewWalkTransform': {'size': [390, 390], 'offset': [14, 107]},
        'generator': 'built-in image_gen',
        'prompts': ['prompt.txt', 'layout-prompt.txt'],
        'correctionEditor': 'PhotoCraft MCP',
        'correctionRecipe': 'photocraft-correction.json',
        'hairPaletteReference': 'assets/characters/hero/sit_down.png',
        'hairPaletteReferenceSha256': hashlib.sha256((RUNTIME / 'sit_down.png').read_bytes()).hexdigest(),
        'source': source.name,
        'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    }
    (FOLDER / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    verify()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    if parser.parse_args().verify:
        verify()
    else:
        main()
