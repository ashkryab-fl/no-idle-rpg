# Bird-feeding rest

The heroine sits on a wooden bench with an open sack of seed beside her and
three sparrows at her boots. The canonical front/back/side references define
her identity; the seated source supplies supplementary proportions and style.
All frames include the bench, sack and birds, with no sword.

## Timeline

| Atlas frame | Action | Duration |
| --- | --- | --- |
| 0–1 | Resting heroine; birds alternate pecking poses | 0.4 s each, repeated four times |
| 2 | Reach toward the sack | 0.18 s |
| 3 | Hand inside sack, gathering seed | 0.24 s |
| 4 | Lift a handful | 0.18 s |
| 5 | Begin underhand toss | 0.14 s |
| 6 | Scatter seed in front of boots | 0.18 s |
| 7 | Retract hand while birds eat | 0.18 s |

The 4.3-second loop repeats without replaying entry. Pecking animates throughout
the 3.2-second pause between handfuls. Return interrupts any pecking pose
immediately; an active handful finishes first, within 1.1 seconds.

## Graph

`HeroFeedBirdsRestGraph.definition()` stops after the walking step, holds standing
for 0.3 s, crossfades to the bench for 0.5 s, then loops feeding. Return captures
the current feeding pose, crossfades to standing for 0.5 s, holds for 0.3 s, and
finishes with `readyToTravel`. Adventure remains blocked throughout entry/exit.
Return during the initial standing hold skips the bench; return during entry
fade finishes that fade before exiting.

`HeroRestGraphs.rest()` selects seated, phone, sleeping or feeding rest with
equal weights once per idle session. Debug controls include `Feed birds rest`
for the complete graph and `Feed birds` for the loop alone.

## Assets

- Built-in ImageGen source: `art/hero/feed_birds_v1/source-sheet.png` (RGBA,
  1774 × 887, 4 × 2 grid).
- Recipe: `tool/sprite_assets/manifests/hero/feed_birds_v1.json`.
- Runtime atlas: `assets/characters/hero/feed_birds.png`, eight 512 × 512 cells.
- Rig: anchor (0.5, 0.875), scale 0.23. Packing uses a shared scale/translation
  rather than independently fitting each silhouette.
- Timeline: `lib/content/animations/hero/clips/feed_birds.dart`.

```sh
python3 tool/sprite_assets/build.py tool/sprite_assets/manifests/hero/feed_birds_v1.json --no-previews
python3 tool/sprite_assets/verify.py tool/sprite_assets/manifests/hero/feed_birds_v1.json
flutter test --no-pub test/content/hero_feed_birds_test.dart test/game/hero_animation_preview_test.dart
```

Static atlas checks and graph tests do not establish native visual playback.
