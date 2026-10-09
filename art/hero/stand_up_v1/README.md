# Reluctant stand-up v1

Six distinct generated poses: unfold from sitting and plant the sword; rise
to half-kneeling; push into a crouch; turn while leaning on the sword; lift
the sword into a right-facing stance; begin the first stride.

The **existing** canonical seated frame is held separately for 0.3 seconds.
It is not included in the six-frame sheet and is not regenerated.
Runtime sequence: sharpening → seated → stand-up → walk, starting at walk_00.
Stand-up is a 3072×512 RGBA sheet, six 512×512 frames, 0.25 s/frame,
non-looping (1.5 s total). Anchor (0.5, 0.875), scale 0.25, multiplier 1.05
match the seated pose. All generated poses use one source scale of 0.59.
Translations preserve ground contact and follow the body pivot during turning.

The primary front/rear/profile references were attached during generation.
identity-reference.png combines them for the layout edit. Supporting motion
references were seated_v1/reference.png and walk_v2/source_frames/walk_00.png.
Built-in image_gen produced source-study.png and the selected source-sheet.png.
prompt.txt and layout-prompt.txt record the exact prompts; the layout prompt
also received the identity reference board as image 4.

source_frames/ contains extracted artwork; frames/ contains packed runtime
cells. The original walk and seated artwork remain unchanged. Hidden RGB
colors outside sprites may look like a gradient in alpha-ignorant viewers;
these pixels have zero alpha. alpha-review.png composites the generated sheet
on a solid background to inspect the actual transparency.

## PhotoCraft correction (2026-10-09)

`source-corrected.png` is the build input. `source-sheet.png` retains the
original generated artwork. PhotoCraft MCP applied hair-only RGB curves sampled
against `../../../assets/characters/hero/sit_down.png`, with a separate correction
for the darker rear ponytail, followed by a smooth local head reduction in
the first three poses. The nominal reduction is 14%, fading out at the neck,
the sword-side boundary and the lower body to avoid cutout seams. Frames 3–5
receive only the palette correction.

The hair palette now follows sit-down, including warm champagne highlights and
tan-brown shadows. The earlier front-reference palette correction is superseded.
The three primary design references use the same sit-down palette. Their poses
and the already corrected stand-up head proportions are preserved.
`photocraft-correction.json` records the exact selections, curves and warp
meshes for replay through PhotoCraft's `command_batch`. A normal rebuild only
requires the corrected PNG and ffmpeg. The manifest selects that input and lists crop/placement parameters.
`head-size-comparison.png` shows the original first three frames above the
corrected frames. All previews and extracted cells use the corrected source.

Rebuild/check:

```sh
python3 tool/build_hero_stand_up.py
python3 tool/build_hero_stand_up.py --verify
```

- stand-up-preview.gif: six-frame transition only.
- wake-to-walk-preview.gif: last sharpening pose, neutral seat, all six
  stand-up frames, then the complete existing walk cycle.
- transition-contact.png: neutral seat, six poses, following walk_00.

Preview walking cells are transformed to the seated canvas using the runtime
scale ratio 0.20 / (0.25 × 1.05), with the respective anchors preserved.
This shows the actual relative rendered sizes rather than fitting every pose.
GIF has reduced alpha/color precision; gameplay uses the RGBA PNG.
