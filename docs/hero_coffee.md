# Coffee rest

The heroine drinks coffee in the sword-supported standing pose from
`art/hero/phone_v1/scroll_neutral.png`. Her near glove stays on the planted
sword's pommel; the former phone-holding hand raises and lowers an ivory mug.
The phone neutral/smile frames define the pose and expression; canonical
front/back/side references define identity and palette.

## Timeline and transitions

The six unique poses are: mug at chest, raising, rim at lips, sipping with
closed eyes, lowering, and a contented pause. The runtime sequence is
`0 (3 s) → 1 (0.18 s) → 2 (0.16 s) → 3 (0.55 s) → 2 (0.12 s)
→ 4 (0.18 s) → 5 (0.65 s)`, repeating every **4.84 seconds**.

Entry reuses the actual walking frame 8 and phone frames 0/1 with their original
resources and timing. It then crossfades to the coffee pose for 0.35 s.
The mug-down poses interrupt immediately; an active sip finishes lowering the
mug first (at most 1.19 s). Exit crossfades to standing for 0.35 s and holds
for 0.3 s before `readyToTravel`. Early return during entry skips coffee;
return during its fade finishes the fade before exiting.

`HeroRestGraphs.rest()` selects coffee alongside seated, phone, sleep and
bird-feeding rest, with equal weights once per idle session. Debug choices
`Coffee rest` and `Drink coffee` select the complete graph and loop.

## Assets and verification

- Selected original source: `art/hero/coffee_v1/source-sheet.png`.
- Packing recipe: `tool/sprite_assets/manifests/hero/coffee_v1.json`.
- Runtime atlas: `assets/characters/hero/coffee.png`, six 512 × 512 RGBA cells.
- Rig matches phone: anchor (0.62, 0.875), scale 0.20.
- Packing uses scale 0.7625 and offset (75, 53), calibrated against walking
  and phone frames at their shared rig. Measure boot soles rather than the
  planted sword tip; hair and cape bounds alone do not define ground contact.
  Frame 1 has an extra 1 px vertical offset to keep its sole on the same row
  after resampling. All coffee boot contacts are at atlas y = 438 (alpha ≥ 230),
  compared with walk y = 438–439 and phone resting poses y = 437.
- Timeline: `lib/content/animations/hero/clips/coffee.dart`.
- Graph: `lib/content/animations/hero/coffee_graph.dart`.

```sh
python3 tool/sprite_assets/build.py tool/sprite_assets/manifests/hero/coffee_v1.json --no-previews
python3 tool/sprite_assets/verify.py tool/sprite_assets/manifests/hero/coffee_v1.json
flutter test --no-pub test/content/hero_coffee_test.dart test/game/hero_animation_preview_test.dart
```

Atlas and graph checks do not establish native playback or visual seam quality.

<details>
<summary>Exact built-in ImageGen prompts</summary>

All calls use `transparent_background: true`. Initial inputs, in order:
phone `scroll_neutral.png`, phone `scroll_smile.png`, then canonical
`reference/front.png`, `back.png`, `side.png`. The extraction pass uses the
initial generated sheet. A final pass adds cell margins; only the selected
source is retained.

```text
Use case: precise-object-edit
Asset type: transparent game animation sprite sheet, SIX frames in an exact 3-column by 2-row grid of equal SQUARE cells, row-major, ideally 1536x1024.
Input images: image 1 phone scroll_neutral.png is the EDIT TARGET and exact pose/geometry/style anchor. Image 2 phone scroll_smile.png supplies the slight contented facial expression. Images 3 front, 4 back, 5 side are supporting canonical identity/palette references only, NOT alternate poses.
Primary request: reuse the heroine in the phone-animation pose, but replace the smartphone with a small plain ceramic COFFEE MUG with a visible handle and dark coffee inside, and animate her taking a relaxed sip. She STANDS facing viewer RIGHT in exactly the same three-quarter profile, supporting her weight with the same near gloved hand resting on top of the planted sword pommel. The OTHER, formerly phone-holding hand now holds the mug.
Invariants: exact same large chibi head and compact proportions as edit target; same facial profile, same warm champagne-blonde voluminous wavy single high ponytail, brown bow and jewel, amber eye, red scarf and tattered cape, silver/gold segmented armor and gold chest cross, brown belts/pouch and gloves, short ivory skirt/red panel, stockings and armored boots. The sword is identical to target: long straight silver blade planted TIP DOWN, gold crossguard with central red stone and brown grip. Sword is in front of her on viewer LEFT and stays vertical on exactly the same ground point throughout. Supporting hand NEVER leaves the top of the sword. Both feet stay in the exact same target stance and same positions.
Composition: six copies of the SAME fixed-camera standing heroine on transparent alpha. Identical scale, head position, sword and boot anchors, torso, hair and cape silhouette in all cells. Only the formerly phone-holding forearm, wrist/mug and eyelids/mouth change. Keep mug small, about the width of her gloved fist, consistent size across every frame. Warm ivory ceramic with a brown rim, NO logo, NO letters, NO saucer. Coffee remains inside, no spills. Character including ALL hair, cape, blade tip and boots fits inside each cell with at least 6 percent empty transparent margin on all sides. No cropping. No smartphone anywhere.
Frame 1 top-left: calm neutral rest, open eye looking gently forward/down, mug held upright at upper chest level, well below lips, elbow relaxed, supporting hand remains on sword.
Frame 2 top-middle: lifting mug halfway from chest toward mouth, elbow bends slightly, mug rim a short distance below lips; head/body remain fixed.
Frame 3 top-right: rim of mug JUST TOUCHES her mouth, mug almost upright, eye softly open, a clear readable contact pose, no head movement.
Frame 4 bottom-left: SIPPING, mug rim still touching mouth, mug tilts toward her mouth about 15 degrees, eye gently closed, tiny relaxed smile, hand holds the HANDLE, supporting hand still on sword.
Frame 5 bottom-middle: mug lowered halfway from lips toward chest, upright again, eye opening softly, slight contented expression.
Frame 6 bottom-right: mug back at EXACT same chest-level position as frame 1, brief contented closed-eye smile after the sip. Same pose transitions smoothly back to frame 1 by opening the eye.
Style: retain target's softly shaded detailed 2D anime/chibi illustration, clean fine warm outlines, warm blonde/gold/red palette, same lighting and armor design. Not pixel art, not 3D, not photorealism.
Avoid: redesign, larger/smaller head in different frames, changing hair/cape volume, walking/leaning farther, moving sword or supporting arm, duplicate arms, extra fingers, multiple cups, phone, scenery, ground plane, shadow oval, labels, numbers, text, grid lines, glow, colored background or drawn checkerboard. Actual transparent RGBA.
```

```text
Use case: background-extraction
Edit target: the supplied six-frame coffee animation sprite sheet, 3 columns by 2 rows.
Remove ONLY the entire opaque brown/red gradient backdrop from ALL SIX cells and from inside every gap around hair strands, cape, arms, handle, sword and legs.
Output MUST have REAL TRANSPARENT ALPHA (RGBA). No solid black/white/gray/brown replacement, no drawn checkerboard, no matte halo, no glow, no ground/shadow.
Keep the heroine, mug, planted sword, all six poses, artwork, colors, details and frame order UNCHANGED. Preserve the 3x2 equal-square-cell layout and identical pose alignment. Keep all hair, cape, blade tips, mug and boots fully intact. Clean anti-aliased edges. No labels/text/grid. This is solely transparent background extraction, not a redraw or redesign.
```

```text
Use case: precise-object-edit
Edit this supplied 3x2 SIX-frame coffee animation sprite sheet for production frame isolation.
Keep the SAME exact six poses and artwork. Do NOT change character design, anatomy, expressions, mug, armor, sword, hair or cape.
The current figures extend to cell bottoms. Re-layout each complete figure at 80% of its current size in the CENTER of its own equal SQUARE cell. This must create a clear EMPTY TRANSPARENT BORDER of at least 40 pixels on ALL FOUR sides of EACH 512x512 cell, especially BELOW EVERY BOOT SOLE AND SWORD TIP. All six whole figures use ONE identical scale and ground line within their cells. Rows must be separated by a wide empty transparent gutter. No part of a figure can cross a cell edge into a neighboring cell.
Restore the tiny missing bottom outlines of any boot sole or sword tip at the original sheet edge, matching the original material and shape. Everything must be fully visible.
Output 1536x1024, exact 3 columns x2 rows of512x512, no drawn borders or gridlines, no text or labels.
TRUE RGBA TRANSPARENT background (alpha zero in borders and all space outside figures). No environment, no floor, no gradient or shadow, no background matte. Clean silhouette antialiasing only.
Frame order: mug down, mug raising, rim at lips, sipping eyes closed, mug lowering, mug down contented eyes closed. Planted sword and supporting hand are completely stationary. Preserve original image style/colors/details.
```

</details>

