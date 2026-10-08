# Idle Companion

Робочий desktop idle RPG MVP на Flutter + Flame для macOS та Windows. Поки користувач активний, герой іде, procedural вороги зупиняють рух, автоматичний бій дає Gold, XP і Knowledge Books. Після смерті герой відроджується. Глобальна бездіяльність користувача переводить героя у відпочинок: після завершення поточного encounter він зупиняється й обирає одну idle animation або один граф.

Для героїні підключено прозорі RGBA спрайти: ходьба — 10 кадрів 512×512, 8 FPS; атака та смерть — по 4 кадри; бойова стійка — перший кадр атаки; відпочинок — сідання та цикл точіння меча зі спільною статичною позою. Рухомий фон циклічно показує три панорами: луки з хатиною та млином → струмок → пшеничні поля з дерев’яним парканом. Інші анімації, вороги, hit particles, damage numbers і drops поки мають програмні debug placeholders. Відсутні assets підтримують fallback.

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

Клік по герою відкриває Quick Menu, а постійна кнопка-шестерня відкриває Settings. Statistics, Character Upgrades, Equipment, Settings і Debug Tools відкриваються в тому самому Flutter-вікні. Закриття панелі знову зменшує native window. `Quick Menu → Exit` і `Settings → Save & quit` зберігають прогрес перед виходом. macOS Quit / Cmd-Q та Windows WM_CLOSE також проходять через save handshake.

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

`movement`, `DPS`, `reward` multipliers для кожного idle level зараз 1.0. Вони застосовуються до активного gameplay та завершення поточного encounter; під час відпочинку рух завжди зупинений незалежно від multiplier.

## Структура

```text
lib/
  app/                  Riverpod controller, runtime dependencies, lifecycle orchestration
  core/
    assets/             AssetCatalog, AnimationCatalog, AnimationDefinition
    balance/            ProgressionBalance coefficients; GameBalance timing/rendering
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

Переходи явно перевіряє `GameStateMachine`. Hero death також може бути викликаний debug tools під час travel/approach/reward. Enemy death animation завершується перед розрахунком reward. Смерть відкочує поточний етап на 1 (мінімум 1) та обнуляє stageKills; respawn відновлює full HP. `NoDeathPenalty` зберігає постійний character progress: level, XP, Gold, Books і придбані upgrades/equipment не втрачаються.

**USER_IDLE** визначає бажання відпочивати незалежно від поточної combat phase. Якщо користувач став idle під час encounter, герой завершує approach, бій, death/reward або власний death/respawn, і лише після повернення до `TRAVELING` запускає відпочинок. Idle animation не перекриває бойові анімації. Якщо активність повернулась до завершення encounter, відпочинок не починається.

`GameSimulation.isResting` зупиняє рух, background scroll, накопичення distance та зменшення encounter distance. Нові вороги не спавняться на жодному idle level, включно з Debug Spawn enemy. Рух і спавн відновлюються після повернення до active та завершення поточної idle animation і `hero.caught`. Під час cooldown між доступними idle animations герой також стоїть (`hero.idle` fallback).

`AnimationDefinition.damageEventTime` задає момент damage. Default attack: 0.6 s, damage на 0.35 s. Якщо attack speed швидша за animation duration, timeline прискорюється пропорційно, разом із damage event. Hit reaction, critical visual event, HP change, damage number походять від того самого `DamageEvent`. Events обох бійців впорядковуються за часом удару всередині step; при однаковому часі герой має deterministic tie priority. Attack clock зберігає progress поточного cycle: програмна зміна attack speed у combat не повторює історичні удари. Death animation утримує останній frame у reward/respawn паузі.

Герой програє 4 кадри атаки по 0.15 s: бойова стійка → замах → удар зі слідом меча → завершення. Damage на 0.35 s припадає на третій кадр. Влучання у героя не перериває його swing: короткий світлий flash накладається поверх спрайта. Між атаками та під час stationary pauses `hero.idle` тримає перший кадр — бойову стійку з мечем напоготові. Якщо hit asset відсутній, реакція на влучання поза swing використовує цю стійку зі спалахом.

Смерть героя: 4 кадри — встромляє меч у землю → опускає голову → осідає на коліна → знесилено тримається за меч. Перші три кадри по 0.4 s, остання поза рівно 1 s, загалом 2.2 s. `hero.death` не зациклюється: 0.4 s останнього кадру в HERO_DEATH і 0.6 s утримання в RESPAWN; потім герой відроджується з повним HP. Attack speed не змінює цей темп. Sprite і preview — у `art/hero/death_v1/`, runtime asset — `assets/characters/hero/death.png`.

Simulation використовує delta time accumulator із fixed step, а не frame counts. Traveling distance і background scroll залежать від часу. У approach фон плавно сповільнюється. Після reward герой продовжує рух або відпочиває залежно від активності користувача. Великі suspend gaps (>5 s) не проганяють прихований combat catch-up.

`DesktopGame` зупиняє стандартний Flame ticker через `pauseEngine`, а Timer викликає `stepEngine` із реальним dt. Settings дає 15/30/60 FPS; default 30, 15 — energy-efficient режим. Це обмежує фактичні rendering ticks, а не тільки ігрову швидкість. Debug speed x5/x20 множить simulation dt; activity statistics залишаються wall-clock.

## Balance і progression

Усі числові coefficients бою, етапів, луту, XP, вартості й сили апгрейдів та base enemy values — `lib/core/balance/progression_balance.dart`. `game_balance.dart` містить rendering/timing/platform settings. `EnemyCatalog`, `UpgradeCatalog` і `EquipmentCatalog` містять IDs/names/curves та посилання на ці константи. Widgets не містять progression formulas.

```text
tier = stage - 1
onVictory: kills += 1; stageKills += 1; addXp(character, xpReward)
after 12 stage victories: stage += 1; stageKills = 0
onHeroDeath: stage = max(1, stage - 1); stageKills = 0
enemyHP = baseHP × 1.08^tier
enemyDamage = baseDamage × 1.065^tier
goldReward = baseGold × 1.10^tier
bookDropAmount = baseBooks × 1.10^tier; bookDropChance = 0.28
xpReward = baseXPReward × 1.07^tier
xpRequired(level) = 45 × 1.12^(level - 1)
characterLevelStatMultiplier = 1.015^(level - 1)

upgradeCost(level) = baseCost × costGrowth^level
costGrowth: Gold equipment = 1.1405; Books upgrades = 1.1605
batchCost(level, n) = cost(level) × (costGrowth^n - 1) / (costGrowth - 1)
MAX = floor(log(1 + wallet / cost(level) × (costGrowth - 1)) / log(costGrowth))
```

HUD показує `Stage N · kills/12`. Етап визначає складність ворогів і rewards; XP та character level визначають постійну силу героя (+1.5% HP і damage за рівень, із compound growth). Distance, час, lifetime kills і character level не підвищують етап. Після смерті на Stage 10 герой повертається на початок Stage 9 (0/12), знову вбиває 12 випадкових мобів цього етапу, отримуючи Gold/Books/XP, та повертається на Stage 10. Повторення циклу накопичує валюту й XP для постійних апгрейдів. Смерть на Stage 1 залишає Stage 1 та обнуляє тільки stageKills. Character level/XP, Gold/Books, upgrades/equipment та lifetime kills зберігаються. Формули, джерела та критерії оцінки балансу — [docs/stage_balance.md](docs/stage_balance.md).

MAX працює без sequential level loops; після математичного розрахунку є rounding correction. Для costGrowth = 1 використовується flat-cost формула; для growth дуже близько до 1 — чисельно стабільні expm1/log1p series. Ці крайні випадки також покриті tests. x10 купує до 10 доступних рівнів, показуючи фактичну кількість і сумарну ціну.

Прокачка поступово відстає від enemy HP: ціни Gold/Books ростуть на 14.05%/16.05% за upgrade, а HP/damage — на 5%. Результат 30-денної event simulation із 8 активними годинами на день і збалансованими покупками раз на годину: медіанний час етапу приблизно 2.0 хв на день 1, 2.9 хв на день 14 та 8.1 хв на день 30. Це довгостроковий тренд; випадкові вороги, crit, покупки та deaths змінюють час окремих етапів. Сценарії й обмеження — [docs/stage_balance.md](docs/stage_balance.md); відтворення: `dart run tool/simulate_progression.dart --hours-per-day 8 --seeds 3`.

Books upgrades і equipment contributions додають рівні відповідного stat:

- Damage і Max HP: `base × 1.05^combinedUpgradeLevel × levelStatMultiplier`;
- Crit Chance: `min(0.8, 0.05 + 0.001 × combinedUpgradeLevel)` — +0.1 відсоткового пункту за рівень;
- Crit Damage: `1.5 + 0.01 × combinedUpgradeLevel` — +0.01× за рівень.

Швидкість героя стала: `ProgressionBalance.heroAttackSpeed = 1.0` атака/с. Вона залишається у `CombatStats`, але відсутня у Statistics, character upgrade catalog і equipment catalog. Старі збережені рівні `speed`/`boots` не впливають на характеристики; рівні критів перераховуються за новими коефіцієнтами.

`CombatStats.dps` включає attack speed, crit chance і crit multiplier. UI підписує характеристику, показує фактичний total stat зараз і після вибраної покупки x1/x10/MAX, а також окремий сумарний bonus поточного upgrade/item. Для crit chance бонус вказано у відсоткових пунктах. `InfiniteUpgradeDefinition.effect` застосовує `curve`, `valueGrowth`, `softCapRate` та `bonusPerLevel`; effect formulas знаходяться в domain, не widgets. Equipment slots постійні: Weapon, Armor, Helmet, Amulet. Inventory/equipment replacement відсутні. Кожен слот підтримує x1/x10/MAX.

Gold гарантований, Books мають per-enemy configured chance (default 28%); кількість Gold і Books зростає на 10% за етап, XP на 7%. `EnemyFactory` обчислює всі три нагороди; `DropSystem` застосовує chance для Books і activity multiplier до Gold/Books, XP не множиться. Валюти зберігаються як `Amount`, без округлення кожного drop. `DropSystem` повертає renderer-independent `Reward`. Обґрунтування цін/сили та приклади — [docs/stage_balance.md](docs/stage_balance.md).

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

Save schema version 5. Зберігаються stage/stageKills, character Level/XP/Books/Gold/upgrades/equipment, distance, lifetime kills, activity aggregates, settings і UTC timestamp. `SaveMigrator` підтримує v1–v4: старий `enemyProgressKills` (або lifetime kills за його відсутності) перетворюється на stage/stageKills за колишнім кроком 12 перемог; character progression зберігається. Старий прихований counter видаляється.

Save: раз на хвилину (60 s), після кожного успішного character/equipment upgrade та зміни settings, на lifecycle inactive/paused/detached та перед controlled exit. Exit призупиняє simulation, завершує activity session і чекає save; повторні натискання не запускають паралельний exit. Якщо save або native quit не вдалися, гра відновлюється й показує помилку. Startup error UI теж підтримує native Quit. Force-kill/power-loss може втратити останні ≤60 s. Reset вимагає Flutter confirmation і очищає primary, backup та live progression; instance lock зберігається до виходу.

`OfflineProgressService` повертає `OfflineProgressResult(duration, distance, kills, gold, books)`. MVP обчислює offline duration, але не симулює offline combat і не нараховує offline rewards. Timestamp і result contract уже готові до майбутнього offline model.

## Як розширювати catalogs

### Новий enemy

Додайте числові base values/weights/rewards у `ProgressionBalance`, а `EnemyDefinition` у `EnemyCatalog.definitions` у `game/systems/enemy_spawner.dart`: id/name/baseHp/baseDamage/attackSpeed/critChance/critDamage/rewardGold/rewardXp/rewardBooks/rewardBookChance/difficultyWeight/animations prefix. Factory застосує незалежне HP/damage/Gold/Books/XP scaling; spawner обере definition через weighted random. Зареєструйте animation IDs `prefix.idle/attack/hit/death` у `AnimationCatalog`. Зміни combat не потрібні.

### Character upgrade

Додайте `InfiniteUpgradeDefinition` у `UpgradeCatalog.character`: stable id, name, CharacterStat, baseCost, costGrowth, curve, valueGrowth/softCapRate/bonusPerLevel. Підтримувані статі вже обчислює `CharacterStats.calculate`. Новий тип stat потребує enum + формулу в CharacterStats і display mapping у UpgradeList; widgets не повинні обчислювати effect formulas.

### Equipment upgrade

Додайте `EquipmentDefinition` у `EquipmentCatalog.items`: stable id/name/stat/baseCost/costGrowth/curve. UI автоматично створить fixed слот і x1/x10/MAX controls. Список не створює inventory і не дозволяє замінювати предмети.

### Animation / sprite sheet

`assets/characters/hero/walk.png` уже містить **10 горизонтальних frames, 512×512, 8 FPS** і зареєстрований у pubspec. Окремі кадри збережено в `assets/characters/hero/walk_frames/`, оригінальний sheet, перші 10 кадрів і GIF preview — у `art/hero/walk_v2/`. Повторне складання (потрібні ffmpeg і ffprobe):

```sh
cd /Users/artemshkryab/dev/proj/idle_companion
python3 tool/build_hero_walk.py
python3 tool/build_hero_attack.py
python3 tool/build_hero_death.py
```

Walk-скрипт бере перші два ряди оригінального sheet зліва направо, збільшує кожну повну комірку вдвічі через Lanczos, зберігає позиції та alpha, створює sheet 5120×512 та GIF preview. Attack-скрипт збирає 4×512×512 зі source artwork у `art/hero/attack_v1/`, копіює sheet до `assets/characters/hero/attack.png`, а перший кадр — до `ready.png`. Scale атаки/стійки 0.25 узгоджує висоту героїні з walk (0.20). PNG зареєстровані так:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/characters/hero/walk.png
    - assets/characters/hero/attack.png
    - assets/characters/hero/ready.png
    - assets/characters/hero/death.png
    - assets/characters/hero/sit_down.png
    - assets/characters/hero/seated.png
    - assets/characters/hero/sharpen.png
```

У `AnimationCatalog` замініть definition або передайте override під час створення simulation:

```dart
final animations = AnimationCatalog({
  'hero.walk': const AnimationDefinition(
    id: 'hero.walk',
    asset: 'assets/characters/hero/walk.png',
    frames: 10,
    frameWidth: 512,
    frameHeight: 512,
    stepTime: 1 / 8,
    loop: true,
    anchorX: .62,
    anchorY: .875,
    scale: .20,
  ),
  'hero.attack': const AnimationDefinition(
    id: 'hero.attack',
    asset: 'assets/characters/hero/attack.png',
    frames: 4,
    frameWidth: 512,
    frameHeight: 512,
    stepTime: .15,
    anchorX: .58,
    anchorY: .875,
    scale: .25,
    damageEventTime: .35,
  ),
  'hero.idle': const AnimationDefinition(
    id: 'hero.idle',
    asset: 'assets/characters/hero/ready.png',
    frameWidth: 512,
    frameHeight: 512,
    loop: true,
    anchorX: .58,
    anchorY: .875,
    scale: .25,
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
    sit_down.png seated.png sharpen.png
    idle/a1.png idle/a2.png idle/a3.png idle/b.png idle/c.png idle/d.png
    caught_slacking.png
  enemies/enemy_01/
    idle.png attack.png hit.png death.png
  environment/
    background_meadow_01.png background_stream_02.png background_wheat_03.png
  effects/
  ui/
```

Paths не пов'язані із combat logic: animation IDs і enemy prefixes є stable contracts. `AssetCatalog.backgrounds` задає порядок трьох bundled панорам. Кожна відображається у viewport 400×133.33 зі співвідношенням 3:1 та невеликим перекриттям із нижньою доріжкою; цикл довжиною 1200 logical pixels керується `GameSimulation.distance`, тому не скидається на межі кожних 400 pixels та зупиняється під час бою й відпочинку. Якщо жоден фон не завантажився, використовується procedural fallback. Effects/UI files додаються до власних visual components.

### Idle chains

`IdleAnimationCatalog.definitions` — список вузлів із weight, idle level, cooldown, loop count та правилами переривання. `nextAnimationId` задає лінійний chain, `nextAnimationIds` — випадковий вибір продовження. Зареєструйте visual timelines у `AnimationCatalog`.

```dart
const IdleAnimationDefinition(
  id: 'hero.a1', requiredIdleLevel: IdleLevel.level1,
  nextAnimationId: 'hero.a2', canInterrupt: false,
);
// a2 → a3, a3 без nextAnimationId
```

Selection обирає weighted root chain або standalone animation, а не довільний її child. Після configured duration × loop count та `holdLastFrame` система вибирає доступне продовження за його weight, idle level і cooldown. Якщо продовження недоступні, утримує завершену позу. Конструктор перевіряє thresholds, duplicate IDs, weights, loop counts, cooldowns, targets та cycles. AnimationCatalog перевіряє finite timeline/geometry та узгодженість ключа й ID. User return interrupt-ить тільки `canInterrupt` animation; інакше чекає завершення поточного вузла, потім `hero.caught` placeholder і normal gameplay.

Поточний граф: `hero.sitDown → hero.sharpen`. Сідання має 4 кадри по 0.3 s і додаткову паузу 0.5 s у фінальній позі. Точіння має спільний стартовий кадр сидіння, потім цикл із 4 рухомих кадрів по 0.225 s (центр → зліва → центр → справа) до повернення активності (`loopUntilActivity`). `loopStartFrame: 1` не повторює стартовий кадр у кожному циклі; non-looping сідання утримує останній кадр. Для нових варіантів додайте IDs до `nextAnimationIds` сідання та задайте ваги дочірніх вузлів. Останній кадр сідання і перший кадр продовження — точні копії `art/hero/seated_v1/reference.png`. [Референс, промпти, previews і контракт розширення](docs/hero_rest.md). Власний каталог можна передати через `GameSimulation(idleDefinitions: definitions)`.

## Debug tools

Доступні лише `kDebugMode`: Spawn enemy, Kill enemy, Kill hero, +100 Gold, +100 Books, +100 XP, idle Active/Level1/Level2/Level3/OS, x1/x5/x20, hitboxes, state/idle/animation labels. Override не зберігається; OS повертає native polling. Override керує відпочинком і поверненням до пригод, але activity statistics завжди класифікуються за реальною native activity. Debug tools не входять у release Quick Menu.

Settings має окремі sliders Background opacity, Road opacity та Overall opacity (0–100%). Загальна прозорість множить прозорість персонажів, ефектів, HUD, фону й дороги. При 0% залишається кнопка-шестерня; відкрита панель Settings не згасає, щоб можна було повернути видимість. Прихований герой пропускає кліки на desktop також у native layer. Значення зберігаються після завершення перетягування; старі сейви використовують 100%, а Reset повертає всі три значення до 100%.

Ґрунтова доріжка `assets/environment/road_dirt_01.png` має прозорі краї та відображається вузькою смугою під персонажами поверх ландшафту. Її offset, як і offset фону, залежить від `GameSimulation.distance`, тому обидва рухаються та зупиняються разом.

Sound preference зберігається, але audio playback поки не реалізовано. Launch at startup — видимий disabled placeholder. `flame_audio` буде додано пізніше.

## Перевірка та відомі межі

- `flutter analyze --no-pub`: без issues (2026-10-08).
- Попередня повна перевірка `flutter test --no-pub`: **72 tests passed**, включно зі stage scaling, HUD rollback, повторним farming Stage 10 → 9 → 10, save migration, no-assets Flame startup, hero walk/attack/death/guard asset loading, death sequence 2.2 s з фінальним кадром 1 s, damage на slash frame при звичайній та прискореній атаці, guard між ударами, Exit/retry/failure/reset collision, invalid saves, chronological combat timing, програмні зміни швидкості, death frame hold, idle graph validation та near-linear MAX.
- Після перегляду економіки та місячного темпу прогресу: **90 tests passed** у повному `flutter test --no-pub`, включно з 30-денною симуляцією та новими idle assets. Global analyzer без issues; pixel regression перевіряє незмінність завершеної пози сидіння протягом паузи. Event simulation перевіряє баланс за 8 і 24 активні години на день; тривалий ручний playtest не проводився.
- Після фіксації attack speed та зменшення критів: **95 tests passed** у повному `flutter test --no-pub`; `dart analyze lib test tool` і `git diff --check` без issues. Перевірено старі speed/boots levels, кроки +0.1 п.п. / +0.01×, cap 80%, UI previews x1/x10/MAX і відповідність preview фактичній покупці на ширині 400 px. 30-денні scenarios оновлені; новий macOS build/live runtime для цих змін ще не перевірено.
- Попередній macOS debug build: успішний для попередніх змін (2026-10-08). **Release build успішний**: `flutter build macos --release --no-pub`, app 20.8 MB, arm64. Поточні Release/Profile обирають одну native Flutter-supported architecture через Xcode settings (arm64e host → arm64, Intel → x86_64). На Xcode 27 штатний `lipo -verify_arch arm64 x86_64` fails despite both slices present; universal build потребує окремого сумісного tooling verification. Intel mapping написано, але Intel build на цьому Apple Silicon Mac не перевірено.
- macOS runtime: перевірено travel/combat/death/reward, панелі Statistics/Upgrades/Equipment/Settings/Debug, purchases, idle override та global idle reset після input у Finder без focus companion. Після Save & quit/restart збережений equipment level відновився; native Quit menu також завершив save handshake. У поточному **release runtime** перевірено Quick Menu без Debug Tools, equipment item effect, відновлення Weapon Lv 1 і Quick Menu **Exit**. Exit записав новий lastSaveTime і завершив app process; гра після перевірки закрита.
- Windows C++ implementation написано, але Windows build/runtime на macOS **не перевірено**. Потрібен Windows host для validation Win32 transparency, click-through, DPI/taskbar behavior і WM_CLOSE save handshake.
- Hot-plug кількох monitor, зміна resolution і Dock/taskbar position реалізовані через notifications/messages, але live display-topology matrix не перевірялась. Monitor picker не входить до MVP.
- macOS alpha та Windows binary transparency різняться; Windows per-pixel alpha compositing — описане вище обмеження.
- Final sprite sheets, production balancing, audio, auto-launch і offline combat — наступні етапи.

[Checklist усіх 34 пунктів і pending platform matrix](docs/requirements_checklist.md).

Tests покривають XP/level-up, upgrade cost/x10/MAX, crit/event timing, enemy/reward scaling, book drop chance, idle thresholds/chains/interruption, activity sessions/local midnight/suspend, save/load/backup/migration, offline infrastructure, enormous number formatting і FPS-independent simulation outcomes.

API references: [FlameGame](https://docs.flame-engine.org/latest/flame/game.html), [Flame image/animation API](https://docs.flame-engine.org/latest/flame/rendering/images.html), [Flutter macOS controller](https://api.flutter.dev/macos-embedder/interface_flutter_view_controller.html), [Apple idle timestamps](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)), [Win32 GetLastInputInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getlastinputinfo).
