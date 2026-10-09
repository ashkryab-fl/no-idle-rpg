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

`AnimationDefinition.scaleMultiplier` defaults to `1` and corrects the rendered
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

Register the clip/frames in `lib/content/animations/animation_resources.dart`
and add a node plus a `GraphChoice` in
`lib/content/animations/hero/rest_graphs.dart`. Both Select nodes have explicit
waiting HoldPose fallbacks. For example, after authoring reading artwork, the
activity Select can contain:

```dart
GraphChoice(id: const VariantId('hero.sharpen.seated'),
  target: HeroRestGraphs.sharpen, weight: 3),
GraphChoice(id: const VariantId('hero.read.seated'),
  target: const NodeId('rest.read'), weight: 1),
```

Add `LoopClip(id: NodeId('rest.read'), clipId: ClipId('hero.read'), ...)` and an
ordered `ActivityReturned` edge to its cleanup or the shared exit hold. Reading
and sharpening then have 25% and 75% weights among eligible choices. Exact pose
contracts refer to a shared frame; family contracts establish compatible pose
geometry. An activity with a different exit pose needs a cleanup clip back to
`seatedNeutral`. The validator checks contracts through Select branches too.

`RestPolicy` supplies eligibility and `WeightedVariantSelector` uses injected
Random. Choice conditions use typed facts, such as `rest.idleLevel`; core playback
has no idle thresholds. Cooldown declares its own `CooldownKey`, duration and
`CooldownStart.started` or `.completed`. The optional `completionNode` names the
last cleanup node; by default completion is when the selected target exits,
including an interruption. Nodes sharing a clip never implicitly share cooldown.

Selection happens once at Select entry. When all candidates are blocked, the
fallback holds the same pose without re-entry or a lottery every render frame.
Author an explicit signal edge from fallback back to Select when eligibility
changes. The default graph uses `rest.selectionChanged`; the compatibility
adapter emits it on idle-level changes. A caller enabling cooldown-limited
variants must also signal retry when cooldown eligibility changes.

The entry lasts 4 × 0.3 s plus a 0.5 s shared HoldPose. Returning during entry
queues activityReturned until both complete. Sharpening interrupts immediately;
its 0.225 s neutral intro plays only once, then frames 1–4 loop every 0.9 s.
Return goes through a separate 0.3 s neutral HoldPose, stand-up Select,
6 × 0.25 s PlayClip and `Finish(readyToTravel)`. Neutral is outside those six
stand-up frames. Duplicate return signals do not restart exit, and new inactivity
cannot jump from a half-standing pose into sitting. Death/reset cancel playback
and pending signals; a new rest starts from the entry.

The runner carries remaining dt between nodes and reports any remainder after
Finish. RestCoordinator keeps adventure blocked until the typed `readyToTravel` event.
HeroAnimationCoordinator starts walking at `walk_00`, advances it by the remaining
part of the step and returns exactly that travel time for distance/scroll/spawn.
Inactivity during exit finishes standing before a new rest entry consumes the
remaining time. Death/reset cancel graph signals and bump playback generation.

ActorComponent reads a resolved PlaybackSnapshot with frame, rig and overlay;
it never computes frameIndex or elapsed time. FlameSpriteFrameCache loads each
PNG once and shares the same Sprite for sit-down end, HoldPose and sharpening
intro. No synthetic SpriteAnimation is created for a hold. Damage flash is an
independent overlay; combat uses one AttackPlayback clock for frame and marker.
Installed PNGs/geometry remain unchanged. Real-asset loading and pixel hold
regressions passed in widget tests; no live desktop/native alpha check was run.

Explicit `GameSimulation(idleDefinitions: ...)` still uses the separate legacy
adapter, including nextAnimationId/nextAnimationIds and a legacy return delay
on the existing guard pose. Unregistered legacy nodes fail validation; test
fixtures declare debug frames explicitly outside production content.
These compatibility APIs will be removed in stage 5. The current default graph
uses the typed catalog. See [the refactoring plan](animation_architecture_plan.md).
Artwork, prompts and complete seam preview:
[stand-up v1](../art/hero/stand_up_v1/README.md).

## Rebuild and check

```sh
python3 tool/build_hero_rest.py
python3 tool/build_hero_rest.py --verify
python3 tool/build_hero_stand_up.py
python3 tool/build_hero_stand_up.py --verify
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
