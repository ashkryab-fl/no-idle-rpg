# Meadow sequence

Generated using the built-in image_gen tool with the first meadow as the
reference. The complete prompt set is in `prompts.txt`.

Sequence: meadow (01) → stream (02) → wheat (03) → meadow (01).

- `assets/environment/background_meadow_01.png`: existing 2172 × 724 PNG.
- `assets/environment/background_stream_02.png`: new 2172 × 724 PNG.
- `assets/environment/background_wheat_03.png`: new 2171 × 724 PNG.

Open `preview.html` for the animated sequence, a 400 × 120 game-sized preview,
and all three transitions side by side. Each segment is displayed at the same
size; the one-pixel native width difference of segment 03 is normalized by the
display dimensions. The image files have not been resampled or edited by code.

Visual inspection found no obvious seam in the three transitions. Edge pixels
are not identical: mean RGB boundary differences are 4.70/255 for 01 → 02,
4.50/255 for 02 → 03, and 5.62/255 for 03 → 01. This is visual continuity,
not a guarantee of pixel-identical borders. Assets are connected to the Flutter
renderer through AssetCatalog.backgrounds and ScrollingEnvironment. No existing
artwork was replaced.
