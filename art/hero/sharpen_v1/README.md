# Seated sword sharpening

The heroine faces the camera and moves a whetstone along the sword lying on
her lap. `source-sheet.png` is the selected generated 2×2 pose sheet with clear
transparent gutters. All motion poses use the same scale and seated baseline.

`sharpen.png` is a 2560×512 RGBA sheet with five frames at 0.225 s/frame:
shared seated reference, middle, near guard, middle, near tip.
Frame 0 is copied from `../seated_v1/reference.png` and played once. Frames
1–4 repeat via `loopStartFrame: 1`, keeping the stone in hand across cycles.

`sharpen-preview.gif` repeats the four active frames (0.9 s/cycle).
`frames/` contains all five separate PNGs. The graph selects this continuation
after sit-down and loops until activity returns, without repeating sit-down.

Artwork uses the built-in imagegen tool. `prompt.txt` records pose generation;
`spacing-prompt.txt` records the layout correction. The exact shared frame,
source transforms and timeline are in `../sit_down_v1/manifest.json`.

Rebuild/check: `python3 tool/build_hero_rest.py [--verify]`.
See [random continuations](../../../docs/hero_rest.md).
