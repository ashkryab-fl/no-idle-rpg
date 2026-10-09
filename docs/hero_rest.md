# Seated rest animations

The default rest graph runs through `AnimationGraphRunner` and has an explicit
entry node: `hero.sitDown → HoldPose → Select seated activity`.
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

`SpriteFrameDefinition.scaleMultiplier` defaults to `1` and corrects the rendered
size around the sprite anchor. Sharpening and the static seated pose use `1.05`.
The final sit-down frame and all graph holds reference `PoseId.seatedNeutral`;
its frame geometry applies the seated multiplier while preserving ground contact.
The renderer no longer needs a sit-down-specific correction.

Artwork was generated with the built-in `imagegen` tool. Saved prompt set:

- [Initial seated identity study](../art/hero/seated_v1/prompt.txt).
- [Sit-down transition](../art/hero/sit_down_v1/prompt.txt).
- [Sharpening poses](../art/hero/sharpen_v1/prompt.txt).
- [Sharpening sheet spacing correction](../art/hero/sharpen_v1/spacing-prompt.txt).

The initial `source-seated.png` study guided generation. The final canonical
pose is selected from the same rig as the moving hands to preserve continuity.

## Add an activity or stand-up variant

Static resources live in `lib/content/animations/hero/poses.dart`, timelines in
`hero/clips.dart`, and selection metadata in `hero/variants.dart`. The default
resources still contains the original eight real PNG clips; procedural enemies
retain their explicit Canvas timeline outside the sprite catalog.

`HeroRestVariant` declares a stable VariantId, separate NodeId/ClipId,
entry/exit pose contracts, weight, allowed typed facts (`rest.idleLevel`),
interruption policy and optional cooldown. Cooldown has an explicit key and
started/completed timing; variants sharing one clip never implicitly share it.
An optional cleanupClip/cleanupNode returns an activity to exact seatedNeutral,
and completed cooldown timing waits until that cleanup node exits.

`HeroRestGraphs.seatedRest(activities: ..., standUps: ..., resources: ...)`
assembles LoopClip/cleanup and PlayClip nodes from those descriptions. It validates
metadata against actual clip pose contracts and validates all graph branches.
No change to the generic runner, semantic coordinator or renderer is needed
for another descriptor. Runtime content remains typed Dart; asset manifests
contain only PNG packing parameters. References/prompts stay in separate files;
preview frames, rigs and timing are read from Dart by
`tool/export_animation_previews.dart`.

RestPolicy controls eligibility and the injected WeightedVariantSelector draws
only on Select entry. A blocked selection stays in one waiting HoldPose;
RestCoordinator emits selectionChanged once conditions become eligible, including
an exact cooldown expiry inside a large dt. Checking eligibility consumes no RNG.
The runner exposes its next time boundary so the policy scheduler does not
reimplement clip clocks. Returning during a wait still takes the normal exit.

The default entry lasts 4 × 0.3 s plus a 0.5 s shared HoldPose. Returning during
entry queues activityReturned until both complete. Ordinary sharpening interrupts
immediately; its 0.225 s neutral intro plays once, then frames 1–4 loop every 0.9 s.
Return goes through a separate 0.3 s neutral HoldPose, stand-up Select,
6 × 0.25 s PlayClip and Finish(readyToTravel). Neutral is outside those six frames.
Duplicate returns do not restart exit; new inactivity finishes standing before a
new sit. Death/reset discard playback/signals and increment generation.

RestCoordinator blocks adventure until readyToTravel and passes remaining dt to
HeroAnimationCoordinator. Walking starts at walk_00 and consumes only that
remainder; distance/scroll/countdown use exactly the returned travel time.
ActorComponent draws PlaybackSnapshot frame/rig/overlay. SpriteFrameCache loads
each PNG once and shares canonical seated Sprite across sit-down, hold, intro
and cleanup. AttackPlayback owns both attack visuals and damage marker timing.

The opt-in [second activity and stand-up demo](../art/hero/rest_variants_v1/README.md)
uses real existing frames at different cadences, with a cleanup back to neutral.
`demoAnimationResources()` and `HeroRestGraphs.authoringDemo()` enable it through
content injection; the ordinary game keeps its original variant choices.
Automated tests cover source/rig contracts, weighted eligibility, cooldown retry,
cleanup timing, eight-PNG cache reuse and 30/60 FPS × x1/x5/x20 parity.

Inject `GameSimulation(resources: ..., restGraph: ...)` for alternative content.
RestCoordinator uses only the graph API; there are no idle definitions, exit
sequences, compatibility clocks or return delays. A HoldPose snapshot exposes
PoseId/FrameId with null ClipId. Display labels describe the rest graph and stay
stable across its seams; debug UI exposes the actual clip/node/pose separately.
Strict resource lookup never creates fallback content; sprite sheets require an
asset and debug placeholders require an explicit debug frame declaration.
Sprite enemies declare typed idle/attack/death IDs; procedural enemies explicitly
declare their Canvas attack/death timelines. CombatSystem advances the injected
coordinator clocks and does not resolve content by enemy prefix.
See [migration status and remaining live checks](animation_architecture_plan.md).
New visual seams still need live desktop review. A pose-family label or a local
world-scale preview does not prove matching head proportions or smooth motion.

## Rebuild and check

```sh
python3 tool/build_hero_rest.py
python3 tool/build_hero_rest.py --verify
python3 tool/build_hero_stand_up.py
python3 tool/build_hero_stand_up.py --verify
python3 tool/sprite_assets/verify.py --previews
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

All previous build commands are thin wrappers over the
[shared manifest pipeline](../tool/sprite_assets/README.md). Exact current PNGs
were reproduced in a separate output tree; primary references, prompts and raw
art remain untouched. Previews align actual anchors and world scale rather than
fitting each silhouette independently. Live native desktop checks remain pending.
