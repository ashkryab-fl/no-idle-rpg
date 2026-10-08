# Hero walk v1

Eight separately generated chibi walk-right frames based on the supplied reference.
Generation used the built-in image_gen tool; prompts are saved in prompts.json.
reference.png is the original visual reference. contact_b_reference.png is the
opposite-stride intermediate used to generate the selected second-half frames.
source_frames/walk_00.png through walk_07.png are full-resolution RGBA outputs.

The gameplay sheet is assets/characters/hero/walk.png: 2048×256, eight horizontal
256×256 frames, 8 FPS (0.125 seconds per frame), looping. Normalized individual
PNGs are in assets/characters/hero/walk_frames/. walk-preview.gif previews the loop;
GIF has reduced color/alpha precision, while the gameplay PNG keeps full RGBA.

From the repository root, with ffmpeg and ffprobe installed:

```sh
python3 tool/build_hero_walk.py
python3 tool/build_hero_walk.py --check
```

All resizing, padding, alpha cleanup and assembly are performed with ffmpeg.
Python only inspects pixel/alpha metadata and orchestrates commands. A common
scale and horizontal origin preserve character placement; planted boots are
aligned at y=244. manifest.json records every frame transform and Flame metadata.
The script removes very faint alpha flecks below 16, retains transparent margins,
and verifies that each sheet cell exactly matches its separate normalized PNG.

The sheet assembly command is:

```sh
ffmpeg -y -framerate 8 -start_number 0 \
  -i assets/characters/hero/walk_frames/walk_%02d.png \
  -vf 'tile=8x1:nb_frames=8:padding=0:margin=0' \
  -frames:v 1 -pix_fmt rgba -update 1 assets/characters/hero/walk.png
```

hero.walk is registered in pubspec.yaml and AnimationCatalog. Other animation
states still use their existing procedural placeholders.
