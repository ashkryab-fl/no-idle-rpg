# Audit вимог MVP

Дата: 2026-10-08. Відповідає 34 пунктам наданого specification.

**Реалізовано** означає наявність робочого code path і зазначеного evidence. **Native без live перевірки** означає, що implementation є, але поточний Mac не доводить Windows runtime або multi-monitor matrix. Assets/audio/offline combat не належать до обов'язкової реалізації цієї версії.

| № | Вимога | Реалізація / evidence |
|---|---|---|
| 1 | Desktop overlay | Swift/AppKit та C++/Win32: borderless, transparency, topmost, lower-right work area. macOS runtime перевірено; Windows і hot-plug matrix не перевірено. Windows використовує binary color-key, monitor picker відсутній. |
| 2 | Asset rendering | Installed hero PNGs only; SpriteFrameCache loads real frames by FrameId and shares canonical seated Sprite. ActorComponent renders snapshot frame/rig/overlay, без frameIndex або SpriteAnimation. Missing declared PNG/invalid atlas rectangle відхиляються; widget loading/pixel tests. Вороги — explicit procedural Canvas timeline. |
| 3 | Gameplay loop | GameSimulation, background scrolling, random encounter distance, smooth approach; simulation tests і macOS runtime. |
| 4 | Combat/event timing | CombatSystem/AttackClock, crit, hit reaction, DamageEvent, HP; tests timing, speed change та chronological ordering. |
| 5 | Death/respawn | Hero death: 4 RGBA кадри по 0.4 s, sword plant → head bow → collapse to knees. Остання поза 1 s (0.4 s кадру + 0.6 s RESPAWN), загалом 2.2 s. Full-HP respawn, попередній Stage із 0/12; character level/XP/currencies/upgrades зберігаються. Timing/farming regression tests. |
| 6 | Procedural enemies | EnemyDefinition/Factory/Spawner, weighted random, exponential HP/damage/rewards від Stage. Stage зростає після 12 перемог; смерть відкочує на початок попереднього Stage (мінімум 1), потрібні всі 12 перемог заново. Formula/scenario tests, джерела у stage_balance.md. |
| 7 | Global activity | CGEventSource + duration-only IOHIDSystem, Win32 GetLastInputInfo; macOS input у Finder без focus companion перевірено. Windows не перевірено. |
| 8 | Idle levels | Configurable thresholds 30/120/300s; threshold tests, debug override. |
| 9 | Idle graph | Data-driven chains/roots і weighted continuations, cooldown, loop count, final-pose hold та loop до активності; branch/cooldown/cycle/interruption tests. |
| 10 | User return | Typed immediate/afterCycle/afterClip; shared neutral pose → six-frame stand → readyToTravel. Duplicate samples не restart-ять exit; inactivity завершує вставання перед новим rest. Legacy return delay використовує наявну guard pose. |
| 11 | Idle/rest behavior | Після encounter distance/scroll/countdown/spawn зупинені. Стандартний typed graph: sit → shared HoldPose → weighted activity → neutral HoldPose → six-frame stand → readyToTravel/walk_00. HeroAnimationCoordinator/RestCoordinator передають залишок dt у walk/travel; policy/selector мають explicit cooldown scope; graph/domain/simulation тести. Explicit legacy idleDefinitions лишаються adapter до етапу 5. Debug override не змінює real activity aggregates; live desktop playback інтеграції ще не перевірено. |
| 12 | Click/menu | Hero/menu hit regions, Flutter panel, transparent background click-through; Swift/C++ region bounds narrowed for expanded panel. Windows behavior не перевірено. |
| 13 | Character statistics | Damage/HP/crit та progression у StatisticsPanel; attack speed прихована й зафіксована програмно на 1 атаці/с. |
| 14 | Activity statistics | Aggregates, session means, local midnight, total retention, suspend gaps; unit tests. |
| 15 | Books progression | Four upgradable character stats, permanent levels, Books currency; XP/effect/cost/purchase tests. |
| 16 | Upgrade scaling | Generic cost/effect curves, crit chance cap 80%, +0.1 п.п. crit chance та +0.01× crit damage за рівень, domain formulas; tests near-linear/flat growth і high levels. |
| 17 | Character level | XP geometric requirements, carry-over, +1.5% HP/damage за level, level-up healing; постійний progress незалежний від Stage. Level-up/scaling/farming tests. |
| 18 | Equipment | Fixed Weapon/Armor/Helmet/Amulet, no inventory/replacement; Boots і апгрейд швидкості прибрані. |
| 19 | Gold upgrades | x1/x10/MAX, analytic geometric sum, named item bonus + total current stat + purchase preview; purchase tests. |
| 20 | Drops | Independent Reward/DropSystem; Gold/Books +10% за Stage, XP +7%, Books chance default 28%. Activity multiplier впливає на Gold/Books. Formula/farming/large-number tests. |
| 21 | Large numbers | Amount log10 abstraction, formatter suffix/scientific notation; huge-number tests. Metadata levels мають technical precision bound 2^53−1, описаний у README. |
| 22 | Persistence | Repository, synchronous snapshot + serialized I/O, backup, schema v5 із stage/stageKills та migration v1–v4, single-instance lock, minute autosave / every successful upgrade / lifecycle / exit saves; round-trip/recovery/invalid-state/Exit tests та збереження відкоту Stage після смерті. |
| 23 | Offline infrastructure | OfflineProgressService/Result із duration та майбутніми rewards; no fabricated offline combat; tests. |
| 24 | Architecture | Pure-Dart domain/systems, Flutter presentation/Riverpod orchestration, Flame components, native service adapters. |
| 25 | State machine | Explicit tested transition graph; USER_IDLE orthogonal, пояснення у README. |
| 26 | FPS/energy | Fixed simulation step, actual capped renderer 15/30/60, suspend guard; cross-FPS and invalid-delta tests. |
| 27 | UI/settings | All panels; topmost/sound/FPS, background/road/overall opacity sliders, persistent settings button and readable Settings at 0%, hidden hero click-through, startup placeholder, confirmed reset, save/exit. |
| 28 | Debug tools | All specified actions/idle/speed/hitboxes; menu only in debug. Release runtime: Debug Tools відсутні; Quick Menu Exit зберігає стан і завершує процес. |
| 29 | Balance configs | ProgressionBalance — окремий файл усіх combat/progression/loot/cost/power coefficients та numeric catalog values; GameBalance — rendering/timing/platform. Формули поза widgets. |
| 30 | Tests | Після economy/constants та місячного pacing: **95 tests passed**, повний flutter test --no-pub. Global analyzer без issues; fixed hero speed, crit steps/cap та x1/x10/MAX purchase previews перевірені tests; перевірено weighted continuations, seated reference seam і незмінні pixels під час final-pose hold. 30-денна event simulation за 8/24 активні години на день збережена в docs/progression_pacing_30_days.json. Long-run ручний playtest ще потрібен. |
| 31 | README | Launch/build instructions, native behavior/limitations, architecture/formulas/catalog extensions. |
| 32 | Asset example | Реальні walk (10 кадрів), attack/death (по 4 кадри) і статична бойова стійка; registration/pubspec, source artwork, окремі PNG, GIF та повторювані ffmpeg pipelines. |
| 33 | Working vertical slice | Existing macOS runtime: travel→combat→death→reward, idle, UI, upgrades, save/restart. Assets не потрібні. |
| 34 | Work order/validation | Architecture і vertical slice завершені; цей audit продовжує fixes, analyzer/tests, builds/runtime і documentation. macOS arm64 release build успішний (20.8 MB), app закрито після runtime-перевірки. Windows build можливий лише на Windows host. |

## Наступна platform matrix

- Windows: release build, GetLastInputInfo із companion unfocused, color-key edges, transparent background clicks, DPI 100/150/200%, taskbar на різних edges, WM_CLOSE save/restart.
- macOS: hot-plug/disconnect monitors, resolution scaling, Dock position/autohide changes, fullscreen Spaces, pointer boundaries.
- Universal macOS distribution: Flutter 3.44 + Xcode 27 `lipo -verify_arch arm64 x86_64` fails despite both slices present. MVP Release/Profile обирають одну Flutter-supported native architecture (arm64/arm64e → arm64, x86_64 → x86_64); universal assembly needs a verified compatible tooling version.

Ці перевірки не позначено як успішні без evidence. Audio, launch-at-startup native integration, final art і offline combat — explicit future stages.
