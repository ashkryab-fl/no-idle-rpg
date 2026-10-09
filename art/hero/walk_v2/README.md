# Hero walk v2

The first ten frames of the user-supplied sheet replace the previous walk cycle.
reference.png preserves the complete original 1280×1280 RGBA sheet.
source_frames/walk_00.png through walk_09.png are exact 256×256 cells: row 1,
columns 1–5, followed by row 2, columns 1–5. No other frames are used.

Each full cell is upscaled exactly 2× using ffmpeg Lanczos to 512×512.
Positions, poses, natural vertical motion and transparent margins are preserved;
frames are not individually fitted or repositioned. Lanczos interpolation does
not invent additional artwork detail.

The gameplay sheet is assets/characters/hero/walk.png: 5120×512, ten horizontal
512×512 RGBA cells, 8 FPS, looping (1.25 seconds). The original frame rate stays
unchanged. Separate runtime PNGs are in assets/characters/hero/walk_frames/.
walk-preview.gif previews the loop with reduced GIF color/alpha precision.
manifest.json contains the ordered source cells, output size/scale and PNG paths.
The ground anchor is (0.62, 0.875), with scale 0.20 keeping the character around
its previous displayed height while placing boots on the ground.

From the repository root, with ffmpeg and ffprobe installed:

```sh
python3 tool/build_hero_walk.py
python3 tool/build_hero_walk.py --check
```

The pipeline re-extracts the original ten cells, upscales, assembles and validates
transparent margins and exact PNG-to-sheet correspondence. All pixel processing
uses ffmpeg; Python orchestrates commands and checks metadata/pixel bytes.

A built-in image_gen upscale was evaluated and rejected for colored edge artifacts,
clipped swords and altered cell geometry. The shipped artwork uses only the supplied
original pixels via Lanczos. The evaluated prompt requested: extract the first ten
frames, preserve every pose and design, upscale each cell to 512×512, use a 5×2
transparent grid, and retain relative positioning without clipping or added frames.
The previous generated source artwork remains in art/hero/walk_v1/.
