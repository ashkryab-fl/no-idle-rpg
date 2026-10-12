# Hero ready pose

`assets/characters/hero/ready.png` is a transparent 512×512 guard pose.
Its source is `art/hero/ready_v1/source-ready.png`; packing uses
`tool/sprite_assets/manifests/hero/ready_v1.json`. Idle shares walk's `.20`
scale and `(.62, .875)` anchor. Attack starts and ends with exact copies of
this pose and shares the same rig.

Rebuild with:

```sh
python3 tool/sprite_assets/build.py tool/sprite_assets/manifests/hero/ready_v1.json --no-previews
```

## Generation

Generated with the built-in `image_gen` tool, with transparency enabled.
Inputs, in order: `walk_frames/walk_00.png`, `reference/front.png`,
`reference/back.png`, `reference/side.png`, and the previous `ready.png`.
The generated canvas was 1254×1254; the packing recipe preserves the whole
canvas, uniformly resizes it, and translates it to match walk's ground line.

<details>
<summary>Generation prompt</summary>

```text
Use case: identity-preserve.
Asset type: ONE transparent game sprite, heroine combat-ready standing pose for idle_companion.
Input images: Image 1 is the installed walk frame, PRIMARY guide for EXACT character scale, proportions, profile view, linework and shading. Images 2,3,4 are canonical design references for identity, costume construction and warm champagne-blonde palette. Image 5 is the OLD ready sprite: use ONLY its action (guard stance, knees slightly bent, sword held diagonally upward in front) and sword shape; do not copy its smaller head/body scale or stockier proportions.
Primary request: regenerate this same heroine in a right-facing combat-ready guard, matching image 1 as if she simply stopped walking and raised the sword. Preserve the walk character's identical large head size, torso size, long high wavy ponytail, face profile, warm creamy champagne hair and tan shadows, amber eyes, red scarf and ragged red cape, silver armor gold trim, gold cross chest emblem, dark brown gloves, layered belts, pouch on her own right hip, white skirt red front gold emblem, stockings, silver gold knee/shin/boot construction. Viewpoint must match walking (near-side face in right-facing profile, a little front visible on torso), not a more frontal view. Focused neutral eyes look right. Stand grounded on both feet, slightly apart, modest knee bend. Hold the existing straight silver sword with gold crossguard and red/brown grip in front, blade pointing up-right at roughly 35 degrees above horizontal. Natural hands and grip.
Style/medium: EXACT illustrated 2D anime/chibi of walk frame; warm fine dark outlines, soft broad painted shading. No style change or extra intricate decoration.
Composition: exactly ONE full-body heroine on square 1024x1024 RGBA canvas, actual transparent background. At this 2x scale, reproduce walk framing: top of ponytail around y=155; head crown around y=225; foot sole ground line y=885-896; stance midpoint near x=630 (62 percent canvas width); head centre near x=650. Keep character body height and head size equal to walk image; slight knee bend okay. Hair and cape trail left. Everything including sword tip stays inside canvas with ample transparent margins. No cropping or automatic tight framing.
Constraints: actual alpha transparency, NO ground plane or ground shadow, no glow, no background colors, no painted checkerboard, no text/watermark. Exactly one ponytail and one sword. Preserve weapon from pose reference. ONE sprite, not a sheet or comparison.
```

</details>
