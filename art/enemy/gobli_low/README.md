# Gobli low attack asset

The supplied `0.png`–`3.png` remain unchanged. PhotoCraft removed the opaque
background, restored the knife blades and all rear-foot claws from the supplied
pixels, corrected head/hand sizes, and aligned the rear support foot.
Neck gaps in poses 2 and 3 were cloned from adjacent skin/scarf pixels. The two
light cloth scraps between the legs in pose 3 were tinted brown with a local
multiply fill, retaining their shading. No generated replacement artwork is used.

`aligned_sources/0.png`–`3.png` are the four finished transparent 512×512 poses.
`attack.png` and `assets/enemies/gobli_low/attack.png` contain seven horizontal
512×512 RGBA cells (3584×512), in the exact order **0 → 1 → 0 → 2 → 3 → 2 → 0**.
`frames/attack_00.png`–`attack_06.png` preserve that same playback order.
`attack-0102320.png` is the separately requested sheet with the same cells.

`attack-preview.gif` retains the original six-frame review sequence.
`attack-preview-0102320.gif` shows the seven-frame sequence at 0.1 s per frame.
Runtime plays the seven frames in 0.6 s; the GIF timing is for visual review.
Repeated pose 0 is retained, including at the loop boundary.
The atlas is registered in pubspec. The spawn catalog contains only the goblin,
the enemy with installed sprite artwork.
`enemy.gobliLow.idle` holds pose 0 throughout approach and between attacks;
`enemy.gobliLow.attack` plays the seven cells once per attack. The damage marker
at 0.35 s lands on pose 3, where the knife is fully extended. Death uses a fade
of pose 0 because no death artwork was supplied. Combat/rewards initially use
the existing low-tier slime baseline.
During approach, the goblin stands at a fixed world position: its screen x
decreases by exactly the distance scrolling the scenery and road. The camera
travels 132 world units at 32 units/s (about 4.125 s), then both stop for combat.

Rear foot contact is **(427, 469)**, with a 0.5 px raster tolerance in x for
pose 2; the shared normalized anchor is `(427/512, 469/512)`.
The measured contact uses alpha ≥ 250 in the rear-foot
region (`x > 390`, `y > 435`): its bottom y and median x in the lowest two solid
rows. `alignment-contact.png` shows the corresponding cross and baseline.
The front foot and bent rear leg retain their authored pose changes.

Size matching references the skull/muzzle outline (excluding the ear), palm
and finger proportions, not the overall character bounding box. Head and hands
use separate local transforms; their positions continue to follow each pose.
Approximate source skull dimensions are 328×361, 349×369, 294×306, 253×261 px.
The recorded transforms bring these to approximately **109×120 px** in each
finished pose. Those dimensions are authoring landmarks, not segmentation
measurements. Ear shapes and fist projection still reflect the supplied poses.

`alignment.json` records scales, selection polygons, local pivots, foot anchors,
and final pixel offsets. `repairs.json` records the restored foot outlines,
whole-pose corrections, neck cloning and pose-3 cloth selections.
`photocraft/*-parts.pcraft` keeps the body and adjusted
head/hand layers before whole-pose alignment at 1536×1536. `*-final.pcraft`
stores the finished 512×512 poses. A 1 px median on the alpha mask followed by
levels 20–235 removed isolated edge noise without filtering the RGB artwork.

Repack the exported PhotoCraft poses from the repository root:

```sh
python3 tool/sprite_assets/build.py art/enemy/gobli_low/manifest.json --no-previews
python3 tool/sprite_assets/verify.py art/enemy/gobli_low/manifest.json
```

Packing only copies finished poses; it does not refit or rescale them. The
manifest is intentionally selected explicitly, so existing hero builds retain
their current scope. Atlas cells, exact repeated poses, transparency, margins,
and rear foot contact were checked. Focused combat/content/cache tests cover
approach guard, impact cell, attack recovery and loading the installed atlas.
The native macOS probe completed and its production renderer captures were
visually checked for approach, extended knife, between-attack guard and fade.
`runtime_review/guard.png` and `playback.txt` retain a scene capture and timeline.
Simulation, economy and monthly progression pacing tests also passed with the
new spawn catalog.

Reproduce native macOS rendering with an isolated temporary save:

```sh
flutter run -d macos --no-pub -t tool/goblin_desktop_probe.dart
```

The probe captures the production game renderer in approach, attack, guard and
death phases into a temporary `idle-goblin-native-*` directory, prints its path
and exits automatically.
