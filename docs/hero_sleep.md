# Sleeping rest

`HeroRestGraphs.rest()` chooses seated, phone, or sleeping rest once per idle
session with equal weights. `HeroSleepRestGraph.definition()` can also be passed
as an explicit `GameSimulation.restGraph`. Debug animation controls include
`Sleep rest` for the complete graph and `Sleep / turn` for the loop alone.

The coordinator finishes the walking step, then plays standing (0.3 s), a
crossfade to bed (0.5 s), and the sleep loop. Returning to activity crossfades
the current sleeping pose to standing (0.5 s), holds standing (0.3 s), and
resumes walking. Travel and encounters remain blocked until `readyToTravel`.
An early return during the initial standing hold skips bed; during the entry
fade it finishes that fade before fading back.

## Frames and timing

The heroine is wrapped in a white duvet. Four distinct poses show her facing
the player, rolling toward the ceiling, rolling away, and facing away.
The timeline is `0 (4 s) → 1 (0.18 s) → 2 (0.18 s) → 3 (4 s) → 2 (0.18 s)
→ 1 (0.18 s) → repeat`. Both settled sides are immediately interruptible;
an active roll finishes at the next settled side before exit, within 0.36 s.

- Source sheet: `art/hero/sleep_v1/source-sheet.png`, generated with built-in
  ImageGen using the canonical heroine references; original 2 × 2 grid, RGBA.
- Exact generation prompt: `art/hero/sleep_v1/generation-prompt.txt`.
- Packing recipe: `tool/sprite_assets/manifests/hero/sleep_v1.json`.
- Runtime atlas: `assets/characters/hero/sleep.png`, four 512 × 512 cells.
- Timelines: `lib/content/animations/hero/clips/sleep.dart`.

## Reusable fades

`FadePose` blends a previous resolved frame into `poseId` over a positive
`duration`. Use `fromPoseId` for an explicit source, especially when the fade is
the graph entry. Otherwise the runner captures the preceding node's current
frame, retaining its original rig and anchor. A fade finishes before accepting
return signals. Connect its `Completed` transition to the next node.

`PlaybackSnapshot` carries both frames, both rigs, and the blend progress.
The renderer adds their weighted premultiplied colors inside an isolated layer,
so overlapping opaque pixels do not darken midway through the transition.

## Validation

```sh
python3 tool/sprite_assets/build.py tool/sprite_assets/manifests/hero/sleep_v1.json --no-previews
python3 tool/sprite_assets/verify.py tool/sprite_assets/manifests/hero/sleep_v1.json
flutter test --no-pub test/content/hero_sleep_test.dart test/game/hero_animation_preview_test.dart
```

These checks cover atlas reproduction, alpha, margins, loop timing, fades,
interruption, and travel blocking. Live desktop playback needs a separate check.
