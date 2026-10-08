# Seated rest animations

The default rest graph is `hero.sitDown → weighted seated activity`.
Currently the only continuation is `hero.sharpen`. The entry plays once;
sharpening repeats until user activity returns. Rest still waits for the current
encounter, and stops movement, scroll and enemy spawning.

## Shared pose and artwork

- `art/hero/seated_v1/reference.png`: canonical **512×512 RGBA** seated pose.
- `art/hero/seated_v1/source-reference.png`: original-size cell of that pose,
  cropped from the selected sharpening sheet for future image generation.
- `assets/characters/hero/seated.png`: identical installed static frame.
- `assets/characters/hero/sit_down.png`: four horizontal 512×512 frames,
  non-looping, 0.3 s/frame, then an additional 0.5 s hold. The last frame is
  visible for 0.8 s before the continuation begins.
- `assets/characters/hero/sharpen.png`: five horizontal 512×512 frames,
  0.225 s/frame. Frame 0 is the shared seated pose, played once on entry.
  Frames 1–4 repeat in a 0.9 s cycle: center, left, center, right.

The PNG files for sit-down frame 3, sharpening frame 0 and static seated pose
are copied **byte-for-byte** from `reference.png`. All three metadata entries
use anchor `(0.5, 0.875)` and scale `0.25`. Future seated activities should
use this same canvas, scale and ground contact, and copy this exact reference
as their first frame. Do not independently fit each pose to the canvas.

`AnimationDefinition.scaleMultiplier` defaults to `1` and corrects the rendered
size around the sprite anchor. Sharpening and the static seated pose use `1.05`.
The renderer also applies the seated multiplier to the final sit-down frame,
including its hold between animations, while preserving ground contact.

Artwork was generated with the built-in `imagegen` tool. Saved prompt set:

- [Initial seated identity study](../art/hero/seated_v1/prompt.txt).
- [Sit-down transition](../art/hero/sit_down_v1/prompt.txt).
- [Sharpening poses](../art/hero/sharpen_v1/prompt.txt).
- [Sharpening sheet spacing correction](../art/hero/sharpen_v1/spacing-prompt.txt).

The initial `source-seated.png` study guided generation. The final canonical
pose is selected from the same rig as the moving hands to preserve continuity.

## Add a random continuation

Add its sprite to `pubspec.yaml` and its timeline to `AnimationCatalog`, then
add an `IdleAnimationDefinition` and list its ID in the entry's
`nextAnimationIds`. For example, after authoring a reading animation:

```dart
const IdleAnimationDefinition(
  id: 'hero.sitDown',
  requiredIdleLevel: IdleLevel.level1,
  nextAnimationIds: ['hero.sharpen', 'hero.read'],
  canInterrupt: false,
  holdLastFrame: .5,
);
const IdleAnimationDefinition(
  id: 'hero.sharpen',
  requiredIdleLevel: IdleLevel.level1,
  weight: 3,
  loopUntilActivity: true,
);
const IdleAnimationDefinition(
  id: 'hero.read',
  requiredIdleLevel: IdleLevel.level1,
  weight: 1,
  loopUntilActivity: true,
);
```

With both eligible, sharpening has a 75% chance and reading 25%. Child nodes
are excluded from root selection, so every choice first goes through sitting.
The same weight/idle-level/cooldown rules apply to roots and continuations.
If all children are blocked, the entry holds its final pose until one is
eligible or the user returns; it does not replay sitting.

`nextAnimationId` remains available for a deterministic chain. Branch targets,
duplicate IDs, loops, holds and indirect cycles are validated; a shared
descendant is allowed. An indefinite activity requires `AnimationDefinition.loop`.
For a shared entry frame followed by a moving loop, set `loopStartFrame: 1`.
The renderer honors the sprite's loop metadata; a non-looping idle entry
clamps to its final frame instead of wrapping just because it is an idle node.

When activity returns during sit-down, the noninterruptible entry completes
before `hero.caught`. During sharpening, it interrupts immediately through
that existing return state. A dedicated stand-up animation remains future art.

## Rebuild and check

```sh
python3 tool/build_hero_rest.py
python3 tool/build_hero_rest.py --verify
```

The script uses ffmpeg for extraction, common scaling, transparent padding,
sheet assembly and GIF previews. It checks alpha and margins, sheet dimensions,
exact cell pixels, runtime copies and the shared seated frame.

Previews:

- `art/hero/sit_down_v1/sit-down-preview.gif`: entry and final hold.
- `art/hero/sharpen_v1/sharpen-preview.gif`: the active cycle only.
- `art/hero/sit_down_v1/rest-preview.gif`: entry, hold and three active cycles;
  the review GIF then restarts the whole sequence.

Regression tests cover final-frame holding, indefinite playback, weighted
branch choice, child eligibility/cooldown, interruption, cycle validation,
sprite loading and paused adventure progress.
