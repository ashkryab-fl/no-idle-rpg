# Hero attack v1

Four poses for a single sword attack, matching the right-facing walking heroine:

1. Stationary combat guard: planted boots, bent knees, sword raised in front.
2. Raised-sword backswing.
3. Descending strike with a bright white-gold sword trail.
4. Lower follow-through with a fading trail.

`source-sheet.png` is the selected built-in image_gen output, with a 2x2 layout
in reading order. `source-ready.png` replaces its first pose with a separately
edited stationary combat stance. `frames/attack_00.png` through `attack_03.png` are four
512x512 RGBA cells. `attack.png` arranges them horizontally as a 2048x512 PNG.
`attack-preview.gif` previews the sequence with a longer hold on the ready pose;
GIF has reduced color and alpha precision. Use the PNGs for the full alpha.

`manifest.json` contains only source crops, placement and PNG output paths.
`prompts.txt` preserves the image_gen prompts and reference path.

Rebuild the frame files, horizontal sheet and GIF from the selected source:

```sh
python3 tool/build_hero_attack.py
```

The generated layout has uneven spacing. The build extracts four documented
source rectangles, translates them onto a shared 800x800 canvas to align the
pelvis and boots, then applies the same Lanczos scale to all four canvases.
It does not paint, independently resize poses, or remove the background.
It checks transparent cell borders and exact PNG-to-sheet correspondence.
The corrected ready pose is generated on the same relative canvas layout and
resized as a whole to 512x512 and shifted up 8 pixels to align the boot soles
with the other frames; it overrides only frame 00.

The build also installs `assets/characters/hero/attack.png` and `ready.png`.
They are registered as `hero.attack` (four frames, 0.15s each, non-looping)
and `hero.idle` (one static frame). Both use anchor (0.58, 0.875), scale 0.25.
Gameplay damage remains at 0.35s, during frame 2; attack speed scales the
timeline and damage together. The ready pose is held between attacks and
during stationary pauses when no other animation is selected.
The preview holds ready longer than gameplay for reviewing the artwork.

The generated poses are a new interpretation
of the supplied character, not exact pixel-preserving edits of the walk frames.
The selected transparent generation retains some red/yellow edge speckles;
the PNG alpha is valid, but those visible edge artifacts remain in the artwork.
