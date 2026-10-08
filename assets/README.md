Hero walk artwork is available at characters/hero/walk.png: ten horizontal
512x512 RGBA frames, 8 FPS, looping (1.25 seconds). The PNG is registered in
pubspec.yaml and hero.walk metadata is set in lib/core/assets/animation_catalog.dart.
Individual upscaled PNGs are in characters/hero/walk_frames/.
The supplied sheet, first ten original cells, manifest and GIF preview are in
art/hero/walk_v2/. The previous walk artwork is archived in art/hero/walk_v1/.
Rebuild from the repository root: python3 tool/build_hero_walk.py
The script extracts the first two rows in reading order and upscales each full
256x256 cell exactly 2x using ffmpeg Lanczos. It preserves the source placement
and alpha rather than independently fitting each pose.

Backgrounds are registered in pubspec.yaml and AssetCatalog.backgrounds:
environment/background_meadow_01.png, environment/background_stream_02.png,
environment/background_wheat_03.png. They scroll in this order, then loop to
the meadow. Each segment fills a 400x133.33 landscape viewport, preserving the
panorama's 3:1 aspect ratio and ending slightly beneath the road. Travel distance
drives the cycle, so combat and rest pause it with the hero. The procedural
environment is used only if no background segment can be loaded.

environment/road_dirt_01.png is the generated RGBA dirt path. The renderer
uses its central (0,217,2172,290) source rectangle and draws a 400x24 strip
at y=166 below actors, overlapping only the bottom 4px of the scenery. Actors
stand at y=179; HUD sits above the scenery. It scrolls with travel distance. Background and road
opacity are separate saved settings; overall opacity fades all game visuals.
The settings button and open Settings panel remain available at zero opacity.

Hero attack is characters/hero/attack.png: four horizontal 512x512 RGBA frames,
0.15 seconds per frame, non-looping (0.6 seconds). Damage at 0.35 seconds lands
on frame 2, the main sword slash. characters/hero/ready.png is an exact copy of
attack frame 0 and supplies the static hero.idle combat guard between attacks,
during enemy death/reward pauses, and while no rest animation is selected.
Both use anchor (0.58, 0.875) and scale 0.25 to match the walking hero's height.
An incoming hit flashes over the swing; without a dedicated hit asset, the
guard supplies the hit pose. Attack speed scales playback and damage together.
Sources, separate frames and the GIF preview are in art/hero/attack_v1/.
Rebuild/install: python3 tool/build_hero_attack.py

Hero death is characters/hero/death.png: four horizontal 512x512 RGBA frames,
non-looping, 0.4s per frame. The heroine plants the sword, bows her head, sinks
to both knees and rests her weight on the sword. The final frame is visible
for exactly 1.0s: its normal 0.4s and 0.6s in RESPAWN. Total visible sequence
is 2.2s, then full-HP revival. Attack speed does not accelerate this animation.
Anchor (0.58, 0.875) and scale 0.25 match attack/guard. Source, separate frames,
manifest and GIF are in art/hero/death_v1/.
Rebuild/install: python3 tool/build_hero_death.py

Other animation IDs retain their procedural fallback. Future asset layout:
Expected files: characters/hero/{walk,attack,hit,death}.png,
characters/hero/idle/{a1,a2,a3,b,c,d}.png,
enemies/enemy_01/{idle,attack,hit,death}.png,
effects/, ui/.
Register each PNG in pubspec.yaml and assign its path to AnimationDefinition.asset.
