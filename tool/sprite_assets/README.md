# Sprite packing

Python + ffmpeg crop selected source images, place frames on a common transparent
canvas and stitch them into a horizontal sprite sheet. `art/` holds source art,
references, prompts and review previews. The game loads PNGs from `assets/`.

A manifest is just a packing recipe. For example:

```json
{
  "source": "source.png",
  "size": 512,
  "scale": 0.5,
  "frames": [
    {"crop": [0, 0, 512, 512], "offset": [128, 128]},
    {"crop": [512, 0, 512, 512], "offset": [128, 128]}
  ],
  "output": "assets/characters/hero/example.png"
}
```

- `source` resolves beside the manifest. Frame order is array order.
- `crop` is `[x, y, width, height]`; omit it to use the whole image.
- `scale` uniformly resizes the source cell; default is 1.
- `offset` is `[x, y]` placement on the output canvas; default is `[0, 0]`.
- `sourceCanvas` instead places cropped poses on a larger square before resizing
  to `size`. Attack/death use this to preserve their existing artwork.
- A frame can use another `source`/`scale`, or `copy` an existing shared pose.
- `output` resolves from the repository root. Individual frames are saved
  beside the manifest automatically. `copies` preserves local sheet copies. `framesDirectory` overrides the frame folder;
  `exportFrames` copies selected frames to standalone PNGs (attack's ready pose).
- Without `frames`, the recipe produces a single PNG.

There are no references, hashes, runtime rigs or timelines in the recipes.
References and prompts remain separate files. Clips and rigs live in typed Dart.
`tool/export_animation_previews.dart` supplies preview frames, geometry and timing
from that same content; Python aligns their anchors and exports GIFs/contact sheets.
Combat/death previews use longer review holds. Character pixels must not be clipped.

Run from the repository root (Python standard library, ffmpeg/ffprobe, Dart):

```sh
python3 tool/sprite_assets/build.py
python3 tool/sprite_assets/build.py --previews-only
python3 tool/sprite_assets/verify.py --previews
python3 -m unittest tool.sprite_assets.test_pipeline
```

To reproduce PNGs without changing the checkout:

```sh
python3 tool/sprite_assets/build.py --output-root /tmp/idle-companion-sprites --no-previews
python3 tool/sprite_assets/verify.py --output-root /tmp/idle-companion-sprites
```

A positional manifest limits a command to that recipe. Default builds run in
shared-pose dependency order: seated → sit/sharpen → walk/combat/death → stand-up.
Raw archived source crops are retained as authoring files, not regenerated outputs.
The old `tool/build_hero_*.py` commands remain wrappers; `--verify`/`--check` work.

Verification regenerates frames from sources and compares exact PNG bytes,
atlas RGBA cells, exported/shared copies, transparency and margins. Solid pixels
are counted at alpha >= 250. There are no checksums to repin when changing art.
`--previews` also regenerates GIFs/contact sheets and compares exact outputs.
Native desktop playback, alpha/click-through and Windows remain separate checks.

Runtime authoring uses `AnimationResources` directly, injected through
`GameSimulation(resources: ..., restGraph: ...)`. Holds resolve PoseId/FrameId;
clips own timing and damage markers. The pipeline produces content, never a
second player or a runtime string lookup adapter. `spriteSheetResources` requires
an asset; test/debug placeholders are explicit frame declarations.
