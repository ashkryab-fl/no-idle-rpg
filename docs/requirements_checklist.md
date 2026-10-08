# Audit вимог MVP

Дата: 2026-10-08. Відповідає 34 пунктам наданого specification.

**Реалізовано** означає наявність робочого code path і зазначеного evidence. **Native без live перевірки** означає, що implementation є, але поточний Mac не доводить Windows runtime або multi-monitor matrix. Assets/audio/offline combat не належать до обов'язкової реалізації цієї версії.

| № | Вимога | Реалізація / evidence |
|---|---|---|
| 1 | Desktop overlay | Swift/AppKit та C++/Win32: borderless, transparency, topmost, lower-right work area. macOS runtime перевірено; Windows і hot-plug matrix не перевірено. Windows використовує binary color-key, monitor picker відсутній. |
| 2 | Assets без final artwork | AssetCatalog/AnimationCatalog/AnimationDefinition, Flame Canvas placeholders, no-assets startup widget test. |
| 3 | Gameplay loop | GameSimulation, background scrolling, random encounter distance, smooth approach; simulation tests і macOS runtime. |
| 4 | Combat/event timing | CombatSystem/AttackClock, crit, hit reaction, DamageEvent, HP; tests timing, speed change та chronological ordering. |
| 5 | Death/respawn | Explicit phases, death duration із AnimationCatalog, final frame hold, NoDeathPenalty; regression tests. |
| 6 | Procedural enemies | EnemyDefinition/Factory/Spawner, weighted random, exponential tier scaling; scaling tests. |
| 7 | Global activity | CGEventSource + duration-only IOHIDSystem, Win32 GetLastInputInfo; macOS input у Finder без focus companion перевірено. Windows не перевірено. |
| 8 | Idle levels | Configurable thresholds 30/120/300s; threshold tests, debug override. |
| 9 | Idle graph | Data-driven chains/roots, weights, cooldown, loop count; chain/cooldown/invalid graph tests. |
| 10 | User return | canInterrupt та caught placeholder; both interruption paths tested. |
| 11 | Idle progression | Orthogonal behavior, configurable movement/DPS/reward multipliers; simulation continues. Debug override не змінює real activity aggregates. |
| 12 | Click/menu | Hero/menu hit regions, Flutter panel, transparent background click-through; Swift/C++ region bounds narrowed for expanded panel. Windows behavior не перевірено. |
| 13 | Character statistics | All specified stats у StatisticsPanel; macOS runtime. |
| 14 | Activity statistics | Aggregates, session means, local midnight, total retention, suspend gaps; unit tests. |
| 15 | Books progression | Five character stats, permanent levels, Books currency; XP/effect/cost/purchase tests. |
| 16 | Upgrade scaling | Generic cost/effect curves, soft caps, domain formulas; tests near-linear/flat growth і high levels. |
| 17 | Character level | XP geometric requirements, carry-over, auto stat growth; level-up tests. |
| 18 | Equipment | Fixed Weapon/Armor/Helmet/Boots/Amulet, no inventory/replacement. |
| 19 | Gold upgrades | x1/x10/MAX, analytic geometric sum, item effect + total current stat; purchase tests. |
| 20 | Drops | Independent Reward/DropSystem; Gold guaranteed, Books chance, placeholder visual event; tests 0/1 probabilities. |
| 21 | Large numbers | Amount log10 abstraction, formatter suffix/scientific notation; huge-number tests. Metadata levels мають technical precision bound 2^53−1, описаний у README. |
| 22 | Persistence | Repository, synchronous snapshot + serialized I/O, backup, schema v2 migration, single-instance lock, minute autosave / every successful upgrade / lifecycle / exit saves; round-trip/recovery/invalid-state/Exit tests. |
| 23 | Offline infrastructure | OfflineProgressService/Result із duration та майбутніми rewards; no fabricated offline combat; tests. |
| 24 | Architecture | Pure-Dart domain/systems, Flutter presentation/Riverpod orchestration, Flame components, native service adapters. |
| 25 | State machine | Explicit tested transition graph; USER_IDLE orthogonal, пояснення у README. |
| 26 | FPS/energy | Fixed simulation step, actual capped renderer 15/30/60, suspend guard; cross-FPS and invalid-delta tests. |
| 27 | UI/settings | All panels; topmost/sound/FPS, startup placeholder, confirmed reset, save/exit. |
| 28 | Debug tools | All specified actions/idle/speed/hitboxes; menu only in debug. Release runtime: Debug Tools відсутні; Quick Menu Exit зберігає стан і завершує процес. |
| 29 | Balance configs | GameBalance та definition catalogs; cost/effect/combat formulas поза widgets. |
| 30 | Tests | Original minimum + regression coverage. **46 tests passed**, analyzer no issues. |
| 31 | README | Launch/build instructions, native behavior/limitations, architecture/formulas/catalog extensions. |
| 32 | Asset example | Concrete walk sprite example 8×128×128, 8 FPS, loop, registration/pubspec. |
| 33 | Working vertical slice | Existing macOS runtime: travel→combat→death→reward, idle, UI, upgrades, save/restart. Assets не потрібні. |
| 34 | Work order/validation | Architecture і vertical slice завершені; цей audit продовжує fixes, analyzer/tests, builds/runtime і documentation. macOS arm64 release build успішний (20.8 MB), app закрито після runtime-перевірки. Windows build можливий лише на Windows host. |

## Наступна platform matrix

- Windows: release build, GetLastInputInfo із companion unfocused, color-key edges, transparent background clicks, DPI 100/150/200%, taskbar на різних edges, WM_CLOSE save/restart.
- macOS: hot-plug/disconnect monitors, resolution scaling, Dock position/autohide changes, fullscreen Spaces, pointer boundaries.
- Universal macOS distribution: Flutter 3.44 + Xcode 27 `lipo -verify_arch arm64 x86_64` fails despite both slices present. MVP Release/Profile обирають одну Flutter-supported native architecture (arm64/arm64e → arm64, x86_64 → x86_64); universal assembly needs a verified compatible tooling version.

Ці перевірки не позначено як успішні без evidence. Audio, launch-at-startup native integration, final art і offline combat — explicit future stages.
