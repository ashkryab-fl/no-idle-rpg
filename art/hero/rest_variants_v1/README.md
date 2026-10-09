# Rest variant authoring demo

These are new content descriptions over existing authored artwork; no new PNG
poses, primary references or generated source sheets were invented.
The default game keeps its original rest activity and six-frame stand-up.

`hero.sharpen.slow` reuses neutral → center → left → center → right at
0.45 s/frame. Neutral is an intro only; active frames loop until return, finishing
that cycle before cleanup. The cleanup clip uses right → center → center →
canonical neutral at 0.15 s/frame, ending in the exact shared `seatedNeutral`.
It is eligible from idle level 2, has weight 2, and a 12-second cooldown starting
when cleanup completes. Its cooldown key is independent of the ordinary sharpen.

`hero.standUp.careful` reuses the six stand-up poses at 0.35 s/frame. It follows
the separate 0.3-second neutral hold and exits to standingRight/walk_00. Its
8-second cooldown begins at selection. Ordinary stand-up remains an eligible
alternative, so default demo playback does not lock adventure on a cooldown.

Register new variants in `lib/content/animations/hero/variants.dart`; new clip
sequences go in `hero/clips.dart`, and static artwork contracts in `hero/poses.dart`.
The graph assembles nodes and cleanup from variant metadata. Selection occurs
only on Select entry; RestCoordinator schedules one retry at an eligibility
boundary. No universal runner, actor renderer or clock implementation changes
are required to add another variant.

Opt-in runtime construction:

```dart
final game = GameSimulation(
  animations: AnimationCatalog.fromResources(demoAnimationResources()),
  restGraph: HeroRestGraphs.authoringDemo(),
);
game.idle.setIdleSeconds(120);
```

Reproducible demo and tests:

```sh
python3 tool/sprite_assets/build.py --previews-only
python3 tool/sprite_assets/verify.py --previews
flutter test --no-pub test/game/animation_content_test.dart test/game/sprite_frame_cache_test.dart
```

- `slow-sharpen-preview.gif`: intro, two active cycles, cleanup and neutral hold.
- `careful-stand-preview.gif`: neutral, six stand poses and walk_00.
- `transition-preview.gif`: slow activity → cleanup → neutral → careful stand → walk.
- Corresponding contact sheets use the same world scale and anchors.

There is no packing manifest here: these variants reuse existing PNGs.
`tool/export_animation_previews.dart` reads their frames, rigs and durations from
the actual Dart content. Installed gameplay PNGs are unchanged. Head/ground differences
in the source art are preserved rather than normalized independently per frame.
Local RGBA previews and automated playback/cache tests were checked; these do
not replace live desktop playback or native alpha/click-through validation.
