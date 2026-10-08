# Idle Companion

Робочий desktop idle RPG MVP на Flutter + Flame для macOS та Windows. Герой іде, procedural вороги зупиняють рух, автоматичний бій дає Gold, XP і Knowledge Books. Після смерті герой відроджується. Глобальна бездіяльність користувача перемикає окремий idle animation graph, при цьому прогресія триває.

Sprite assets не потрібні: усі персонажі, рухомий фон, hit particles, damage numbers і drops мають програмні debug placeholders. Фінальне artwork не створювалось.

## Запуск

Перевірений локальний toolchain: Flutter 3.44.0 / Dart 3.12.0, Flame 1.38.2, Riverpod 3.4.3, Xcode 27. `pubspec.lock` фіксує перевірені dependency versions.

macOS 12+:

```sh
flutter config --enable-macos-desktop
flutter pub get
flutter run -d macos
flutter build macos --release
```

Потрібні Xcode та його command-line tools. Deployment target піднято до 12.0: Xcode 27 більше не збирає шаблонний 10.15.

Windows 10 1607+ / Windows 11, на Windows host:

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
flutter build windows --release
```

Потрібен Visual Studio з workload **Desktop development with C++**, Windows SDK і CMake. Native Win32 runner використовує `GetDpiForWindow`.

```sh
flutter analyze
flutter test
```

Клік по герою або `…` відкриває Quick Menu. Statistics, Character Upgrades, Equipment, Settings і Debug Tools відкриваються в тому самому Flutter-вікні. Закриття панелі знову зменшує native window. `Quick Menu → Exit` і `Settings → Save & quit` зберігають прогрес перед виходом. macOS Quit / Cmd-Q та Windows WM_CLOSE також проходять через save handshake.

## Overlay та platform layer

`lib/platform/` містить `DesktopWindowService` і `UserActivityService`. Один MethodChannel `idle_companion/desktop` з'єднує application orchestration з native implementations. Flame components не викликають platform APIs.

### macOS

`macos/Runner/MainFlutterWindow.swift`:

- `NSWindow` із `.borderless`, `isOpaque = false`, `backgroundColor = .clear`, без shadow;
- прозорий `FlutterViewController.backgroundColor`;
- `.floating` для always-on-top, `.normal` якщо опцію вимкнено;
- `.canJoinAllSpaces` і `.fullScreenAuxiliary`;
- прив'язка до нижнього правого кута `NSScreen.visibleFrame` із margin 12 logical points, тому Dock не перекривається;
- 400×190 logical points для гри, 400×620 для відкритої панелі; dimensions обмежуються work area;
- screen-parameter notifications повторно обчислюють позицію;
- cursor polling 30 Hz перемикає `ignoresMouseEvents`: у закритому режимі інтерактивні лише hero rectangle і menu button; у відкритому — compact window area;
- AppDelegate відкладає termination до завершення Dart save, після чого native відповідає `reply(toApplicationShouldTerminate:)`.

На MVP macOS обирає primary screen. Monitor picker і збереження вибору конкретного дисплея не реалізовано. При зміні display topology позиція повторно обчислюється на доступному primary screen; після restart гра повертається в правильний кут.

### Windows

`windows/runner/flutter_window.{h,cpp}`:

- `WS_POPUP`, `WS_EX_TOOLWINDOW`, layered window;
- `SetWindowPos(HWND_TOPMOST/HWND_NOTOPMOST)`;
- `MonitorFromWindow` + `MONITORINFO.rcWork` для taskbar-aware позиції;
- logical dimensions масштабує `GetDpiForWindow`;
- `WM_DISPLAYCHANGE`, `WM_SETTINGCHANGE`, `WM_DPICHANGED` повторно позиціонують overlay;
- cursor polling 33 ms перемикає `WS_EX_TRANSPARENT` поза interactive rectangles;
- `WM_CLOSE` надсилає Dart `closeRequested`, дозволяючи зберегти прогрес до `DestroyWindow`.

**MVP Windows transparency:** `SetLayeredWindowAttributes` використовує color key `RGB(1,1,1)`. Flutter малює саме цей колір у порожній області, яка стає прозорою. Sprite/UI pixels залишаються видимими. Це binary color-key transparency: напівпрозорі Flutter елементи composited із key background, а не справжній per-pixel alpha із довільним desktop backdrop. Для production artwork із напівпрозорими краями варто замінити native compositor на DirectComposition/per-pixel-alpha шлях; abstraction для цього вже відокремлений.

Interaction regions у Swift/C++ і Flutter мають однакові координати: герой, menu button та bounds відкритої панелі. Прозорі поля навколо панелі й фон viewport пропускають кліки навіть при відкритій панелі. macOS відстежує `visibleFrame` також при зміні Dock work area. Якщо змінюєте viewport/hero positioning, синхронізуйте ці rectangles. Cursor polling не читає ні клавіші, ні їхній вміст.

## Global user activity

macOS native отримує timestamps через `CGEventSource.secondsSinceLastEventType` та duration-only `IOHIDSystem/HIDIdleTime` через IOKit. Береться мінімум доступних durations. IOKit потрібен як fallback: під час локального sandboxed runtime CoreGraphics timestamps виявились застарілими, тоді як HID idle duration коректно реагував на input в іншій програмі. Жодні event taps, keyboard hooks або keylogger не використовуються.

Windows використовує `GetLastInputInfo` та unsigned DWORD різницю з `GetTickCount`; subtraction коректно обробляє 32-bit wrap boundary. Це idle duration поточної logged-in user session, а не всіх OS sessions.

Dart опитує service раз на секунду. Помилки відображаються в панелі, а не маскуються як успішне activity detection.

Idle thresholds у `GameBalance`:

| User idle | Behavior |
|---|---|
| <30 s | active |
| ≥30 s | level1 |
| ≥120 s | level2 |
| ≥300 s | level3 |

`movement`, `DPS`, `reward` multipliers для кожного idle level зараз 1.0. Їх можна змінити централізовано без змін widgets або rendering.

## Структура

```text
lib/
  app/                  Riverpod controller, runtime dependencies, lifecycle orchestration
  core/
    assets/             AssetCatalog, AnimationCatalog, AnimationDefinition
    balance/            GameBalance
    numbers/            Amount, NumberFormatter
    persistence/        GameSave, migration, repository, instance lock, offline infrastructure
  domain/
    character/          CharacterProgress, CombatStats, stat calculations
    progression/        InfiniteUpgradeDefinition, character upgrade catalog
    equipment/          Fixed equipment definitions
    activity/           Idle graph, activity buckets/session boundaries
    economy/            Reward model
    settings.dart
  game/
    desktop_game.dart   Flame renderer and capped frame scheduler
    components/         Hero/enemy actors, environment, effects
    systems/            State machine, pure-Dart simulation, combat, spawn, drops, progression
  platform/             Native window/activity abstractions and adapters
  presentation/         Overlay, statistics, upgrades, equipment, settings, debug UI
```

Domain, number arithmetic і game systems залежать тільки від Dart. Flame visual components читають simulation model і споживають transient `VisualEvent`s. Riverpod controller сполучає simulation, UI, persistence і platform services; UI snapshot оновлюється 4 Hz, сама симуляція має fixed step 1/60 s.

## State machine та timing

```text
BOOT → TRAVELING → ENEMY_APPROACH → COMBAT → ENEMY_DEATH → REWARD → TRAVELING
                                       ↘ HERO_DEATH → RESPAWN → TRAVELING
```

Переходи явно перевіряє `GameStateMachine`. Hero death також може бути викликаний debug tools під час travel/approach/reward. Enemy death animation завершується перед розрахунком reward. Death penalty має інтерфейс `DeathPolicy`; MVP використовує `NoDeathPenalty` і full-HP respawn.

**USER_IDLE — orthogonal layer**, а не взаємовиключна combat phase. Користувач може стати idle у будь-який момент, зокрема під час бою; idle animation змінює presentation героя, а бойова симуляція працює далі із configurable multipliers. Death animation має пріоритет перед slacking animation.

`AnimationDefinition.damageEventTime` задає момент damage. Default attack: 0.6 s, damage на 0.35 s. Якщо attack speed швидша за animation duration, timeline прискорюється пропорційно, разом із damage event. Hit reaction, critical visual event, HP change, damage number походять від того самого `DamageEvent`. Events обох бійців впорядковуються за часом удару всередині step; при однаковому часі герой має deterministic tie priority. Attack clock зберігає progress поточного cycle: upgrade attack speed у combat не повторює історичні удари. Death animation утримує останній frame у reward/respawn паузі.

Simulation використовує delta time accumulator із fixed step, а не frame counts. Traveling distance і background scroll залежать від часу. У approach фон плавно сповільнюється. Після reward фон знову рухається. Великі suspend gaps (>5 s) не проганяють прихований combat catch-up.

`DesktopGame` зупиняє стандартний Flame ticker через `pauseEngine`, а Timer викликає `stepEngine` із реальним dt. Settings дає 15/30/60 FPS; default 30, 15 — energy-efficient режим. Це обмежує фактичні rendering ticks, а не тільки ігрову швидкість. Debug speed x5/x20 множить simulation dt; activity statistics залишаються wall-clock.

## Balance і progression

Центральні coefficients — `lib/core/balance/game_balance.dart`. Base enemy data — `EnemyCatalog`, upgrade costs — `UpgradeCatalog` і `EquipmentCatalog`. Widgets не містять progression formulas.

```text
tier = max(floor(distance / 500), kills ~/ 12)
enemyHP = baseHP × 1.08^tier
enemyDamage = baseDamage × 1.065^tier
goldReward = baseGold × 1.07^tier
xpReward = baseXPReward × 1.07^tier
xpRequired(level) = 45 × 1.12^(level - 1)
characterLevelStatMultiplier = 1.015^(level - 1)

upgradeCost(level) = baseCost × costGrowth^level
batchCost(level, n) = cost(level) × (costGrowth^n - 1) / (costGrowth - 1)
MAX = floor(log(1 + wallet / cost(level) × (costGrowth - 1)) / log(costGrowth))
```

MAX працює без sequential level loops; після математичного розрахунку є rounding correction. Для costGrowth = 1 використовується flat-cost формула; для growth дуже близько до 1 — чисельно стабільні expm1/log1p series. Ці крайні випадки також покриті tests. x10 купує до 10 доступних рівнів, показуючи фактичну кількість і сумарну ціну.

Books upgrades і equipment contributions додають рівні відповідного stat:

- Damage і Max HP: `base × 1.05^combinedUpgradeLevel × levelStatMultiplier`;
- Attack Speed: `5 - (5 - baseSpeed) × exp(-0.035 × combinedUpgradeLevel)`;
- Crit Chance: `0.8 - (0.8 - baseChance) × exp(-0.035 × combinedUpgradeLevel)`;
- Crit Damage: `1.5 + 0.035 × combinedUpgradeLevel`.

`CombatStats.dps` включає attack speed, crit chance і crit multiplier. UI показує фактичний total stat із character та equipment contributions, а також окремий effect поточного upgrade/item. `InfiniteUpgradeDefinition.effect` застосовує `curve`, `valueGrowth`, `softCapRate` та `bonusPerLevel`; effect formulas знаходяться в domain, не widgets. Equipment slots постійні: Weapon, Armor, Boots, Helmet, Amulet. Inventory/equipment replacement відсутні. Кожен слот підтримує x1/x10/MAX.

Gold гарантований, Books мають per-enemy configured chance. `DropSystem` повертає renderer-independent `Reward`. Placeholder pickup label можна замінити coin/book effects, не змінюючи економіку.

### Великі числа

Звичайний `double` переповнився б при довгій exponential progression. `Amount` зберігає невід'ємну величину у log10-space. Наприклад, HP 1e12000 має finite stored exponent 12000. Combat, currency, XP, costs і rewards використовують цей abstraction; UI використовує `NumberFormatter` (`K/M/B/T/Qa/...`, далі scientific notation).

Це приблизно 15 significant digits, а не arbitrary-precision decimal. Додавання дуже малого drop до набагато більшої currency може губитися нижче precision. Level counters — exact practical integer metadata, не великий економічний value; захисний arithmetic ceiling 2^53−1 забезпечує точність математичних bulk purchases, без gameplay max-level tuning. Distance/time — bounded real-world double aggregates. Для подальшого переходу на decimal/big-number backend достатньо замінити `Amount` та formatter, не widgets/combat contracts.

## Activity statistics

`ActivityStatisticsService` зберігає агрегати та незавершену session boundary, без input events.

- active → idle завершує active session;
- idle → active завершує idle session;
- averages рахуються по завершених sessions;
- local midnight ділить duration між локальними днями, today bucket reset, total зберігається;
- якщо session перетинає midnight, today's completed-session mean включає лише частину цієї session поточного дня, total mean — весь її duration;
- startup закриває збережену session, нова починається з першого live sample;
- poll/suspend gap >10 s або clock rollback закриває session і не вигадує computer activity за пропущений час;
- точність classification boundary обмежена 1-second polling interval.

## Persistence та offline infrastructure

`GameSaveRepository` дозволяє замінити storage backend. `FileGameSaveRepository` використовує application support directory через `path_provider`, підкаталог `idle_companion`:

```text
save.json             primary
save.backup.json      last known good previous snapshot
save.tmp              flushed temporary write
instance.lock         exclusive OS lock for process lifetime
```

Main startup бере instance lock: одночасні процеси не повинні перезаписувати progression один одного. Writes serialized, JSON snapshot захоплюється до asynchronous I/O. На macOS rename atomic; на Windows replacement потребує delete + rename, тож backup захищає від crash між ними. Якщо primary пошкоджений, load пробує backup. Перевіряються не тільки JSON syntax, а й finite/nonnegative durations/distance, kill count, character та upgrade levels. Помилка запису backup не замовчується як помилка JSON. Якщо обидва пошкоджені або schema новіша — показується startup error із Retry/confirmed Reset, automatic overwrite немає.

Save schema version 2. `SaveMigrator` мігрує v1 → v2, додаючи missing settings/activity; наступні migrations додаються в одному місці. Зберігаються Level, XP, Books, Gold, upgrades, equipment levels, distance, kills, activity aggregates, settings і UTC timestamp.

Save: раз на хвилину (60 s), після кожного успішного character/equipment upgrade та зміни settings, на lifecycle inactive/paused/detached та перед controlled exit. Exit призупиняє simulation, завершує activity session і чекає save; повторні натискання не запускають паралельний exit. Якщо save або native quit не вдалися, гра відновлюється й показує помилку. Startup error UI теж підтримує native Quit. Force-kill/power-loss може втратити останні ≤60 s. Reset вимагає Flutter confirmation і очищає primary, backup та live progression; instance lock зберігається до виходу.

`OfflineProgressService` повертає `OfflineProgressResult(duration, distance, kills, gold, books)`. MVP обчислює offline duration, але не симулює offline combat і не нараховує offline rewards. Timestamp і result contract уже готові до майбутнього offline model.

## Як розширювати catalogs

### Новий enemy

Додайте `EnemyDefinition` у `EnemyCatalog.definitions` у `game/systems/enemy_spawner.dart`: id/name/baseHp/baseDamage/attackSpeed/critChance/critDamage/rewardGold/rewardXp/rewardBookChance/difficultyWeight/animations prefix. Factory застосує scaling; spawner обере definition через weighted random. Зареєструйте animation IDs `prefix.idle/attack/hit/death` у `AnimationCatalog`. Зміни combat не потрібні.

### Character upgrade

Додайте `InfiniteUpgradeDefinition` у `UpgradeCatalog.character`: stable id, name, CharacterStat, baseCost, costGrowth, curve, valueGrowth/softCapRate/bonusPerLevel. Підтримувані статі вже обчислює `CharacterStats.calculate`. Новий тип stat потребує enum + формулу в CharacterStats і display mapping у UpgradeList; widgets не повинні обчислювати effect formulas.

### Equipment upgrade

Додайте `EquipmentDefinition` у `EquipmentCatalog.items`: stable id/name/stat/baseCost/costGrowth/curve. UI автоматично створить fixed слот і x1/x10/MAX controls. Список не створює inventory і не дозволяє замінювати предмети.

### Animation / sprite sheet

Покладіть, наприклад, `assets/characters/hero/walk.png`: **8 горизонтальних frames, 128×128, 8 FPS**. Зареєструйте тільки наявний файл у pubspec:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/characters/hero/walk.png
```

У `AnimationCatalog` замініть definition або передайте override під час створення simulation:

```dart
final animations = AnimationCatalog({
  'hero.walk': const AnimationDefinition(
    id: 'hero.walk',
    asset: 'assets/characters/hero/walk.png',
    frames: 8,
    frameWidth: 128,
    frameHeight: 128,
    stepTime: 1 / 8,
    loop: true,
    anchorX: .5,
    anchorY: 1,
    scale: .55,
  ),
  'hero.attack': const AnimationDefinition(
    id: 'hero.attack',
    asset: 'assets/characters/hero/attack.png',
    frames: 6,
    stepTime: .1,
    damageEventTime: .35,
  ),
});
final simulation = GameSimulation(animations: animations);
```

`DesktopGame` читає Flutter asset manifest, loads через Flame `SpriteAnimationData.sequenced` та використовує actor timeline. Відсутній asset/некоректний sprite завжди має placeholder fallback. `anchor` і `scale` належать rendering metadata. Для idle graph repeated loops renderer повторює frames відповідно до chain duration. Attack playback rate і damage event синхронізовані.

Очікувана future layout:

```text
assets/
  characters/hero/
    walk.png attack.png hit.png death.png
    idle/a1.png idle/a2.png idle/a3.png idle/b.png idle/c.png idle/d.png
    caught_slacking.png
  enemies/enemy_01/
    idle.png attack.png hit.png death.png
  environment/background_01.png
  effects/
  ui/
```

Paths не пов'язані із combat logic: animation IDs і enemy prefixes є stable contracts. `background_01.png`, якщо bundled, автоматично замінить scrolling environment placeholder. Effects/UI files додаються до власних visual components.

### Idle chains

`IdleAnimationCatalog.definitions` — список `IdleAnimationDefinition(id, requiredIdleLevel, weight, nextAnimationId, canInterrupt, minLoops, maxLoops, cooldown)`. Зареєструйте visual timelines у `AnimationCatalog`.

```dart
const IdleAnimationDefinition(
  id: 'hero.a1', requiredIdleLevel: IdleLevel.level1,
  nextAnimationId: 'hero.a2', canInterrupt: false,
);
// a2 → a3, a3 без nextAnimationId
```

Selection обирає weighted root chain або standalone animation, а не довільний її child. `nextAnimationId` проходиться після завершення configured duration × randomly selected loop count. Cooldown застосовується до наступного вибору root. Конструктор перевіряє thresholds, duplicate IDs, weights, loop counts, cooldowns, наявність next ID та відсутність cycles. AnimationCatalog перевіряє finite timeline/geometry та узгодженість ключа й ID. User return interrupt-ить тільки `canInterrupt` animation; інакше чекає завершення поточного вузла, потім `hero.caught` placeholder і normal gameplay.

## Debug tools

Доступні лише `kDebugMode`: Spawn enemy, Kill enemy, Kill hero, +100 Gold, +100 Books, +100 XP, idle Active/Level1/Level2/Level3/OS, x1/x5/x20, hitboxes, state/idle/animation labels. Override не зберігається; OS повертає native polling. Override змінює visual idle behavior, але activity statistics завжди класифікуються за реальною native activity. Debug tools не входять у release Quick Menu.

Sound preference зберігається, але audio playback поки не реалізовано. Launch at startup — видимий disabled placeholder. `flame_audio` буде додано пізніше.

## Перевірка та відомі межі

- `flutter analyze --no-pub`: без issues (2026-10-08).
- `flutter test --no-pub`: **46 tests passed**, включно з no-assets Flame startup, Exit/retry/failure/reset collision, invalid saves, chronological combat timing, speed upgrades, death frame hold, idle graph validation та near-linear MAX.
- macOS debug build: успішний на цьому Mac у попередній перевірці. **Release build успішний**: `flutter build macos --release --no-pub`, app 20.8 MB, arm64. Поточні Release/Profile обирають одну native Flutter-supported architecture через Xcode settings (arm64e host → arm64, Intel → x86_64). На Xcode 27 штатний `lipo -verify_arch arm64 x86_64` fails despite both slices present; universal build потребує окремого сумісного tooling verification. Intel mapping написано, але Intel build на цьому Apple Silicon Mac не перевірено.
- macOS runtime: перевірено travel/combat/death/reward, панелі Statistics/Upgrades/Equipment/Settings/Debug, purchases, idle override та global idle reset після input у Finder без focus companion. Після Save & quit/restart збережений equipment level відновився; native Quit menu також завершив save handshake. У поточному **release runtime** перевірено Quick Menu без Debug Tools, equipment item effect, відновлення Weapon Lv 1 і Quick Menu **Exit**. Exit записав новий lastSaveTime і завершив app process; гра після перевірки закрита.
- Windows C++ implementation написано, але Windows build/runtime на macOS **не перевірено**. Потрібен Windows host для validation Win32 transparency, click-through, DPI/taskbar behavior і WM_CLOSE save handshake.
- Hot-plug кількох monitor, зміна resolution і Dock/taskbar position реалізовані через notifications/messages, але live display-topology matrix не перевірялась. Monitor picker не входить до MVP.
- macOS alpha та Windows binary transparency різняться; Windows per-pixel alpha compositing — описане вище обмеження.
- Final sprite sheets, production balancing, audio, auto-launch і offline combat — наступні етапи.

[Checklist усіх 34 пунктів і pending platform matrix](docs/requirements_checklist.md).

Tests покривають XP/level-up, upgrade cost/x10/MAX, crit/event timing, enemy/reward scaling, book drop chance, idle thresholds/chains/interruption, activity sessions/local midnight/suspend, save/load/backup/migration, offline infrastructure, enormous number formatting і FPS-independent simulation outcomes.

API references: [FlameGame](https://docs.flame-engine.org/latest/flame/game.html), [Flame image/animation API](https://docs.flame-engine.org/latest/flame/rendering/images.html), [Flutter macOS controller](https://api.flutter.dev/macos-embedder/interface_flutter_view_controller.html), [Apple idle timestamps](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)), [Win32 GetLastInputInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getlastinputinfo).
