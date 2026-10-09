# Hero death v1

Four right-facing poses: plant sword, bow head, sink to knees, defeated kneel
with both hands on the planted sword. Generated with built-in image_gen using
the approved combat guard as the character reference; prompt is in `prompt.txt`.

`source-sheet.png` preserves the generated 2x2 layout. `frames/death_00.png`
through `death_03.png` are transparent 512x512 RGBA PNGs. `death.png` and the
runtime copy `assets/characters/hero/death.png` are horizontal 2048x512 sheets.
The build translates complete source rectangles onto a shared 940x940 canvas
to align the sword point and ground, then scales every canvas equally. It
preserves the shorter kneeling silhouette; no pose is independently enlarged.
Some colored edge speckles from transparent generation remain in the artwork.

The first three visible frames last 0.4s each, the final kneeling pose lasts
1.0s, total 2.2s. Runtime `hero.death` is non-looping, four frames at 0.4s,
anchor (0.58, 0.875), scale 0.25. The final frame's normal 0.4s plus the 0.6s
RESPAWN hold make the requested 1.0s before returning at full HP. Attack speed
does not alter death timing. Debug simulation speed still scales game time.
`death-preview.gif` uses the same 0.4/0.4/0.4/1.0 timing, with GIF's reduced
color and alpha precision. Use PNGs for the full alpha.

Rebuild/install from the repository root with ffmpeg and ffprobe available:

```sh
python3 tool/build_hero_death.py
```

The build checks transparent cell borders and exact frame-to-sheet pixels.
`manifest.json` contains only source crops, placement and PNG output paths.
