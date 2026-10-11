# Idle Companion

Робочий desktop idle RPG MVP на Flutter + Flame для macOS та Windows. Поки користувач активний, герой іде, procedural вороги зупиняють рух, автоматичний бій дає Gold; завершення етапів дає Knowledge Books для талантів. Після смерті герой відроджується. Глобальна бездіяльність користувача переводить героя у відпочинок: після завершення поточного encounter він зупиняється й запускає типізований граф відпочинку.

Для героїні підключено прозорі RGBA спрайти: ходьба — 10 кадрів 512×512, 8 FPS; атака та смерть — по 4 кадри; бойова стійка — перший кадр атаки; відпочинок — сідання та цикл точіння меча зі спільною статичною позою. Рухомий фон циклічно показує три панорами: луки з хатиною та млином → струмок → пшеничні поля з дерев’яним парканом. Вороги, hit particles, damage numbers і drops малюються процедурно. Sprite-каталог містить лише встановлені PNG; відсутній заявлений sprite спричиняє помилку завантаження.

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

Клік по герою відкриває Quick Menu, а постійна кнопка-шестерня відкриває Settings. Statistics, Equipment, Talents, Settings і Debug Tools відкриваються в тому самому Flutter-вікні. Закриття панелі знову зменшує native window. `Quick Menu → Exit` і `Settings → Save & quit` зберігають прогрес перед виходом. macOS Quit / Cmd-Q та Windows WM_CLOSE також проходять через save handshake.

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
    animation/          Pure Dart resources, playback snapshot, players, graph/validator/runner
    assets/             AssetCatalog; environment asset paths
    balance/            ProgressionBalance coefficients; GameBalance timing/rendering
    numbers/            Amount, NumberFormatter
    persistence/        GameSave, migration, repository, instance lock
  content/animations/   Installed sprites, hero rest graph, procedural enemy timelines
  game/animation/       Semantic coordinators and Flame SpriteFrameCache
  domain/
    character/          CharacterProgress, CombatStats, stat calculations
    progression/        UpgradePrice geometric financial math
    equipment/          Fixed equipment definitions
    activity/           Rest coordinator/policy/selector, activity statistics
    economy/            Reward model
    settings.dart
  game/
    desktop_game.dart   Flame renderer and capped frame scheduler
    components/         Hero/enemy actors, environment, effects
    systems/            State machine, pure-Dart simulation, combat, spawn, drops, progression
  platform/             Native window/activity abstractions and adapters
  presentation/         Overlay, statistics, equipment, settings, debug UI
```

Domain, number arithmetic і game systems залежать тільки від Dart. Flame visual components читають simulation model і споживають transient `VisualEvent`s. Riverpod controller сполучає simulation, UI, persistence і platform services; UI snapshot оновлюється 4 Hz, сама симуляція має fixed step 1/60 s.

## State machine та timing

```text
BOOT → TRAVELING → ENEMY_APPROACH → COMBAT → ENEMY_DEATH → REWARD → TRAVELING
                                       ↘ HERO_DEATH → RESPAWN → TRAVELING
```

Переходи явно перевіряє `GameStateMachine`. Hero death також може бути викликаний debug tools під час travel/approach/reward. Enemy death animation завершується перед розрахунком reward. Смерть відкочує поточний етап на 1 (мінімум 1) та обнуляє stageKills; respawn відновлює full HP. `NoDeathPenalty` зберігає постійний character progress: Gold, Books і придбане equipment не втрачаються.

Пул спавну містить лише ворогів із підключеними sprite assets; зараз це `gobli_low`. `EnemyDefinition.scale` задає візуальний масштаб типу ворога (типово 1.0); для гобліна він 0.8. Масштаб застосовується навколо точки контакту із землею до всіх поз. Бос додатково множить його на 1.30 (гоблін-бос: 1.04). ГГ має загальний візуальний множник 1.15 (`GameBalance.heroScale`). Під час `ENEMY_APPROACH` ворог стоїть у кадрі 0, а його screen position зміщується на ту саму дистанцію, що background і road. Швидкість камери — 32 units/s: від `enemySpawnX=386` до `enemyCombatX=254` підхід займає приблизно 4.125 s. Після досягнення бойової позиції камера й ворог зупиняються одночасно.

**USER_IDLE** визначає бажання відпочивати незалежно від поточної combat phase. Якщо користувач став idle під час encounter, герой завершує approach, бій, death/reward або власний death/respawn, і лише після повернення до `TRAVELING` запускає відпочинок. Idle animation не перекриває бойові анімації. Якщо активність повернулась до завершення encounter, відпочинок не починається.

`GameSimulation.isResting` зупиняє рух, background scroll, накопичення distance та зменшення encounter distance. Нові вороги не спавняться на жодному idle level, включно з Debug Spawn enemy. Рух і спавн відновлюються після повернення до active та завершення поточної idle animation та її exit sequence (для сидячого відпочинку: `hero.seated → hero.standUp`). Під час cooldown між доступними idle animations герой також стоїть (`hero.idle` fallback).

`AnimationMarker(kind: AnimationMarkerKind.damage)` у clip задає момент damage. Default attack: 0.6 s, damage на 0.35 s. Якщо attack speed швидша за animation duration, timeline прискорюється пропорційно, разом із damage event. Hit reaction, critical visual event, HP change, damage number походять від того самого `DamageEvent`. Events обох бійців впорядковуються за часом удару всередині step; при однаковому часі герой має deterministic tie priority. Attack clock зберігає progress поточного cycle: програмна зміна attack speed у combat не повторює історичні удари. Death animation утримує останній frame у reward/respawn паузі.

Герой програє 4 кадри атаки по 0.15 s: бойова стійка → замах → удар зі слідом меча → завершення. Damage на 0.35 s припадає на третій кадр. Влучання у героя не перериває його swing: короткий світлий flash накладається поверх спрайта. Між атаками та під час stationary pauses `hero.idle` тримає перший кадр — бойову стійку з мечем напоготові. Якщо hit asset відсутній, реакція на влучання поза swing використовує цю стійку зі спалахом.

Смерть героя: 4 кадри — встромляє меч у землю → опускає голову → осідає на коліна → знесилено тримається за меч. Перші три кадри по 0.4 s, остання поза рівно 1 s, загалом 2.2 s. `hero.death` не зациклюється: 0.4 s останнього кадру в HERO_DEATH і 0.6 s утримання в RESPAWN; потім герой відроджується з повним HP. Attack speed не змінює цей темп. Оригінал — у `art/hero/death_v1/`, тимчасове preview — у `build/animation_previews/hero/death_v1/`, runtime asset — `assets/characters/hero/death.png`.

Simulation використовує delta time accumulator із fixed step, а не frame counts. Traveling distance і background scroll залежать від часу. У approach фон, дорога й ворог зміщуються на однакову дистанцію та зупиняються на бойовій позиції. Після reward герой продовжує рух або відпочиває залежно від активності користувача. Великі suspend gaps (>5 s) не проганяють прихований combat catch-up.

`DesktopGame` зупиняє стандартний Flame ticker через `pauseEngine`, а Timer викликає `stepEngine` із реальним dt. Settings дає 15/30/60 FPS; default 30, 15 — energy-efficient режим. Це обмежує фактичні rendering ticks, а не тільки ігрову швидкість. Debug speed x5/x20 множить simulation dt; activity statistics залишаються wall-clock.

## Balance і progression

[Загальний висновок рефакторингу балансу](docs/balance_refactoring_summary.md).

Бойові, ворожі та фінансові коефіцієнти — `lib/core/balance/progression_balance.dart`. Версійований `EquipmentCurveProfile.candidate` (`phase02_candidate_v1`) містить окремі криві Weapon, Armor, Helmet і Amulet. `CharacterStats.calculate` застосовує їх один раз; runtime і preview використовують цей resolver. `game_balance.dart` містить rendering/timing/platform settings.

```text
tier = stage - 1
onVictory (after enemy death): kill Gold; kills += 1; stageKills += 1
onStageClear: first/repeat/milestone Books, eligible Gold lines and snapshot heal
after 5 stage victories: stage += 1; stageKills = 0
onHeroDeath: stage = max(1, stage - 1); stageKills = 0
effectiveTier = tier (tier ≤ 40); інакше 40 + .35×x + .65×40×ln(1+x/40), x=tier−40
enemyHP = baseHP × 1.08^effectiveTier; enemyDamage = baseDamage × 1.065^effectiveTier
boss: HP ×2.2; damage ×1.2; Gold ×2; enemy crit .12, multiplier 2.0
goldReward = baseGold × 1.10^tier
Books: first clear 3; next two clears 1 each; later clears 0
Books milestones: stages 5, 10, 20 and every further multiple of 20 → 5 each
cost(level) = baseCost × 1.1195^level
batchCost(level, n) = cost(level) × (1.1195^n - 1) / .1195
```

HUD показує `Stage N · Wave W/5`. Перші чотири хвилі — звичайні вороги; п’ята — бос із +30% до розміру, HP ×2.2, damage ×1.2 і Gold ×2. Перемоги не збільшують базові характеристики; лише обраний Stage recovery лікує живого героя після всіх п’яти хвиль. Смерть відкочує Stage на один (мінімум 1), wave на 1/5; Gold/Books, equipment і lifetime kills зберігаються. Respawn відновлює full HP. Armor живому герою додає фактичну deltaMaxHp, до нового max HP; мертвого героя покупка не оживляє. Інші предмети не лікують. Attack speed героя стала: 1 атака/с.

Gold купує тільки чотири зареєстровані предмети. Books купують шість талантів у трьох парах: Boss damage / First-clear Gold, Stage recovery / Crit protection, Shorter travel / Stage Gold. `TalentProfile.candidate` (`phase06_calibrated_v3`) містить незалежні B/τ/R і ціни. Ранги 1–3 відкриваються після першого clear Stage 1/3/5 відповідної пари; 4–6 після 20, 7–10 після 100. Ціна наступного рангу — `3×1.8^n Books`, ефект — `B×(1−exp(−n/3))/(1−exp(−10/3))`. B: .5/1.5/.2/.8/.25/.5.

Купівля не обирає талант і не лікує. Вибір безкоштовний, одна альтернатива або none на пару. Незмінний `StageAttempt` фіксує ID/ранги/ефекти й п’ять ворогів, номінальні Gold rewards та travel distances перед першим продуктивним рухом. Зміни рангу/вибору під час спроби застосовуються до наступної. Equipment діє одразу. Clear/death завершує спробу; rest, suspend і restart зберігають її.

`StageSettlement` — resolver контекстних нагород. Окремі lines: kill Gold, first-clear base (3×nominal boss Gold для всіх build), first-clear talent bonus, stage talent bonus (сума п’яти nominal kills), first/repeat/milestone Books. First-clear/milestone не повторюються. Stage Gold дає бонус лише на першому clear і двох повторних; ці три opportunities витрачаються й без активного таланта. Books за звичайні kills і старий random/exponential drop видалені. Після вичерпання бонусів звичайний kill Gold продовжує оплачувати equipment.

Криві кандидата (`n` — рівень відповідного предмета):

- Weapon/Armor: `E(n)=n` до 100; далі `100 + .5*x + 100*ln(1+x/200)`, `x=n-100`. Damage=`14×1.05^E`, HP=`120×1.05^E`, обчислені через log10 без округлення E.
- Helmet: `c=.05+.001*n` до 200 (25%); далі `.8-.55*exp(-(n-200)/550)`.
- Amulet: `m=1.5+.01*n` до 150 (×3); далі `3+2*ln(1+(n-150)/200)`.

`EquipmentPurchases` перевіряє ID, Gold wallet, count і представлений ефект. Команда повторно рахує quote за поточним станом. x10/MAX можуть купити менше рівнів та оплачують лише фактичний count. MAX використовує closed-form affordability та до 53 probes монотонного аналітичного guard; фінальна перевірка не дозволяє списати Gold за нульовий effect. Технічна межа rank — `2^53−1`. Guard порівнює аналітичну дельту з double precision spacing; продуктового epsilon у production немає. Ціни Weapon/Armor починаються з 20, Helmet з 35, Amulet з 30 Gold.

Equipment UI показує before/after, фактичний count/cost і окремий gain: crit у відсоткових пунктах, multiplier у ×, HP/damage у %. Малі дельти мають додаткову точність. Постійні слоти не створюють inventory або replacement.

Equipment і talents використовують спільний `PurchaseQuote<T>` з валютою, rank/count, пакетною/одиничною ціною, before/after/delta та `PurchaseLimit`. Preview й ціни беруться з domain quote; UI не клонує героя й не рахує ефект покупки повторно. Fractional ціни відображаються для обох валют. x10/MAX показують фактичний пакет; talent preview описує owned ability навіть для inactive альтернативи. Wallet, milestone gate, maximum rank, precision і explicit minimum effect мають різні причини. Production epsilon не введено; експериментальний minimumChanceGain пояснюється в Equipment UI.




### Великі числа

Звичайний `double` переповнився б при довгій exponential progression. `Amount` зберігає невід'ємну величину у log10-space. Наприклад, HP 1e12000 має finite stored exponent 12000. Combat, currency, costs і rewards використовують цей abstraction; UI використовує `NumberFormatter` (`K/M/B/T/Qa/...`, далі scientific notation).

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

## Persistence

`GameSaveRepository` дозволяє замінити storage backend. `FileGameSaveRepository` використовує application support directory через `path_provider`, підкаталог `idle_companion`:

```text
save.json             primary
save.backup.json      last known good previous snapshot
save.tmp              flushed temporary write
instance.lock         exclusive OS lock for process lifetime
```

Main startup бере instance lock: одночасні процеси не повинні перезаписувати progression один одного. Writes serialized, JSON snapshot захоплюється до asynchronous I/O. На macOS rename atomic; на Windows replacement потребує delete + rename, тож backup захищає від crash між ними. Якщо primary пошкоджений, load пробує backup. Перевіряються не тільки JSON syntax, а й finite/nonnegative durations/distance, kill count та рівні покупок. Помилка запису backup не замовчується як помилка JSON. Якщо обидва пошкоджені або schema новіша — показується startup error із Retry/confirmed Reset, automatic overwrite немає.

Save schema version 10. Зберігаються stage/stageKills, Books/Gold/equipment, таланти й queued selection, first-clear frontier, sparse repeat ledger, settlement cursor, незмінна активна спроба, HP і travel/combat/reward/death checkpoint, distance, lifetime kills, activity aggregates, settings і UTC timestamp. Відомі дорелізні v1–v9 primary/backup не мігруються: якщо немає актуального сейву, вони очищаються в serialized queue і гра починається заново. Legacy primary не блокує актуальний backup. Current JSON із полем character `upgrades` (навіть порожнім) є пошкодженим: потрібен валідний current backup або явна помилка. Пошкоджений JSON без читабельної версії не вважається legacy. Future version у primary чи backup блокує автоматичний перезапис. Зайві character level/XP поля ігноруються й не емітуються наступним записом.

Capture копіює mutable character/activity/settings синхронно. Restart зберігає HP і selection snapshot; бойова хвиля відновлюється зі свіжим HP того самого запланованого ворога. Pending enemy death завершує оплату один раз; committed reward тільки відновлює hold. Dead checkpoint відновлює death/respawn без передчасного лікування. Boundary після clear явно має `attempt=null`. Невідомий talent profile або суперечливий cursor викликає recovery error/current backup, без перерахунку saved effects. Exact frame/RNG resume не реалізовано; backup може відкотити весь узгоджений checkpoint.

`FileGameSaveRepository.lastLoadStatus` відрізняє нову гру, current load, backup recovery і legacy reset. Recovery/reset відкривають меню з повідомленням; runtime error і startup notice закриваються окремо. Future/current failures зберігають чинний error flow, без автоматичного початку нової гри.


Save: раз на хвилину (60 s), після кожного успішного character/equipment upgrade та зміни settings, на lifecycle inactive/paused/detached та перед controlled exit. Exit призупиняє simulation, завершує activity session і чекає save; повторні натискання не запускають паралельний exit. Якщо save або native quit не вдалися, гра відновлюється й показує помилку. Startup error UI теж підтримує native Quit. Force-kill/power-loss може втратити останні ≤60 s. Reset вимагає Flutter confirmation і очищає primary, backup та live progression; instance lock зберігається до виходу.

Валюта (Gold/Books) нараховується тільки під час роботи симуляції в запущеному додатку. Після закриття й повторного запуску відновлюється збережений прогрес без нагород за час відсутності. Тривалі паузи під час сну комп’ютера відкидаються без симуляції боїв.

## Як розширювати catalogs

### Новий enemy

Додайте числові base values/weights/rewards у `ProgressionBalance`, а `EnemyDefinition` у `EnemyCatalog.definitions` у `game/systems/enemy_spawner.dart`: id/name/baseHp/baseDamage/attackSpeed/critChance/critDamage/rewardGold/difficultyWeight та typed `EnemyAnimationContent`. Factory застосує незалежне HP/damage/Gold scaling; spawner обере definition через weighted random. Поточні Canvas вороги явно посилаються на `ProceduralEnemyTimelines.content`. Для PNG ворога додайте clips/frames/rigs у resources і задайте `SpriteEnemyAnimationContent(idleId: ..., attackId: ..., deathId: ...)`. Усі три ClipId перевіряються строго; відсутній ресурс спричиняє помилку. Hit reaction лишається overlay.

### Equipment

Каталог має чотири stable IDs: weapon/armor/helmet/amulet. Definition містить name/stat/baseCost/costGrowth; effect належить `EquipmentCurveProfile` і `CharacterStats.calculate`. Команда приймає тільки зареєстрований ID. Зміна формул потребує нової версії профілю, контрольних тестів і baseline. Майбутні Books-таланти матимуть окремий domain contract.

### Animation / sprite sheet

У `art/` зберігаємо лише оригінальні згенеровані зображення та потрібні вихідні зображення/референси. Після створення анімації, перед коммітом, видаляємо звідти всі проміжні файли, вирізані кадри, прев’ю, колажі та дублікати готових спрайтів. Рецепти складання — у `tool/sprite_assets/manifests/hero/`, опис героїні — у [docs/hero_reference.md](docs/hero_reference.md), тимчасові результати — у `build/`.

`assets/characters/hero/walk.png` уже містить **10 горизонтальних frames, 512×512, 8 FPS** і зареєстрований у pubspec. Окремі кадри збережено в `assets/characters/hero/walk_frames/`, оригінальний sheet — у `art/hero/walk_v2/`, тимчасові GIF preview — у `build/animation_previews/hero/walk_v2/`. Повторне складання (потрібні ffmpeg і ffprobe):

```sh
cd /Users/artemshkryab/dev/proj/idle_companion
python3 tool/sprite_assets/build_hero_walk.py
python3 tool/sprite_assets/build_hero_attack.py
python3 tool/sprite_assets/build_hero_death.py
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
    - assets/characters/hero/stand_up.png
```

Production resources зібрані у `lib/content/animations/hero/{poses,clips}.dart`.
`AnimationResources` містить immutable maps із окремими `FrameId`, `RigId`,
`PoseId`, `ClipId`; unknown ID або unresolved reference спричиняє помилку.
`AnimationClipDefinition` задає durations, loop range, pose contracts і markers.
Для горизонтального PNG `spriteSheetResources(asset: ..., id: ClipId(...), ...)`
готує явні rectangles; asset є обов’язковим. Debug placeholders створюються
лише явним `SpriteFrameDefinition.debugPlaceholder` у test/debug content.

Контент інжектується без adapter:

```dart
final resources = demoAnimationResources();
final simulation = GameSimulation(
  resources: resources,
  restGraph: HeroRestGraphs.authoringDemo(),
);
```

`DesktopGame` читає Flutter asset manifest і завантажує кадри/атласи в `FlameSpriteFrameCache`, без SpriteAnimation/FPS/loop metadata. `HeroAnimationCoordinator` обирає death/respawn → combat → rest/exit → locomotion; `ActorComponent` малює лише frame/rig/effects із `PlaybackSnapshot`. Shared FrameId має один Sprite. Відсутній заявлений PNG або rectangle за межами atlas — помилка. Процедурні вороги мають явний Canvas timeline. Hit flash — overlay, а не вигаданий hit clip. Бій використовує той самий `AttackPlayback` clock для видимого кадру і damage marker; retiming зберігає cycle progress та вже виконані події.

Очікувана future layout:

```text
assets/
  characters/hero/
    walk.png attack.png ready.png death.png
    sit_down.png seated.png sharpen.png stand_up.png
  environment/
    background_meadow_01.png background_stream_02.png background_wheat_03.png
  effects/
  ui/
```

Paths не пов'язані із combat logic: typed clip/frame/pose IDs є stable contracts. `AssetCatalog.backgrounds` задає порядок трьох bundled панорам. Кожна відображається у viewport 400×133.33 зі співвідношенням 3:1 та невеликим перекриттям із нижньою доріжкою; цикл довжиною 1200 logical pixels керується `GameSimulation.distance`, тому не скидається на межі кожних 400 pixels та зупиняється під час бою й відпочинку. Якщо жоден фон не завантажився, використовується procedural fallback. Effects/UI files додаються до власних visual components.

### Sprite asset pipeline

`lib/content/animations/hero/{poses,clips,variants,rest_graphs}.dart` розділяє
статичні пози, таймлайни й variant metadata. PNG ворогів додаються лише разом
із реальним artwork; поточні вороги мають окремий procedural timeline.
Універсальний `tool/sprite_assets/{build,verify}.py` читає versioned manifests
лише з параметрами пакування: source, crop, scale, offset, size та output.
Референси й промпти залишаються окремими файлами; rig і таймлайни живуть у Dart.
Прев’ю використовують ті самі Dart-описи. Старі `build_hero_*.py` — thin wrappers.

```sh
python3 tool/sprite_assets/build.py --output-root /tmp/idle-companion-sprites --no-previews
python3 tool/sprite_assets/verify.py --output-root /tmp/idle-companion-sprites
python3 tool/sprite_assets/verify.py --previews
```

Оригінальні зображення та первинні референси збережені; runtime PNG залишені без змін.
Повне перескладання rest потребує відсутнього вихідного sharpening sheet та його рецепта. [Manifest/CLI контракт](tool/sprite_assets/README.md).
[Демо другої seated activity та вставання](docs/rest_variants.md)
використовує окремі описи над наявними PNG, з cleanup до exact seatedNeutral.
Демо вмикається через resources/graph injection і не змінює default choices.

### Idle graphs

Стандартний відпочинок використовує pure Dart `AnimationGraphRunner` і
`HeroRestGraphs.seatedRest()` із явним entry node. Вузли мають окремі `NodeId`:
`PlayClip` сідання → `HoldPose` 0.5 s → weighted `Select` → `LoopClip` точіння.
Return signal веде в `HoldPose` 0.3 s → stand-up `Select` → 6 кадрів `PlayClip`
по 0.25 s → `Finish(readyToTravel)` → `walk_00`. Усі статичні holds посилаються
на `PoseId.seatedNeutral`; вступ точіння не повторюється всередині loop.

Runner переносить залишок dt між вузлами, має ordered typed transitions,
immediate/afterCycle/afterClip, marker events і bounded transition budget.
Сідання разом із фінальною паузою завершується перед виходом; повторні signals
не перезапускають вставання. Death/reset скасовують pending playback. Adventure
movement і spawn залишаються заблокованими до `readyToTravel`. RestCoordinator
повертає залишок dt у HeroAnimationCoordinator: walk починається з frame 0
і проходить залишок step; distance/scroll/countdown використовують лише цей час.
GameSimulation володіє encounter, спавном і застосуванням damage; playback
clock більше не походить із phase elapsed.

Нові seated/stand-up variants додаються через clip resources і
`HeroRestVariant` metadata; graph nodes/GraphChoice збираються контентом. `RestPolicy` контролює eligibility і explicit cooldown key з
точкою початку started/completed; injected `WeightedVariantSelector` обирає
лише при вході в Select. Waiting fallback тримає позу; RestCoordinator автоматично сигналізує retry при
зміні eligibility/cooldown expiry, без lottery кожного кадру.
[Референси, authoring API і перевірки](docs/hero_rest.md).

Production і tests використовують один graph/player API. `GameSimulation.resources`
інжектує typed content, `heroPlayback`/`enemyPlayback` повертають resolved
`PlaybackSnapshot`. HoldPose має FrameId/PoseId і не маскується під clip;
renderer не виконує string lookup або власний playback. CombatSystem отримує
спільні AttackPlayback із coordinators. Death/reset скасовують pending signals,
інкрементують generation; image cache не змінює simulation playback.
Поточний playback не входить у save; міграція saves не потрібна.
[Статус міграції та окремі live/platform перевірки](docs/animation_architecture_plan.md).

## Debug tools

Доступні лише `kDebugMode`: Spawn enemy, Kill enemy, Kill hero, +100 Gold, +100 Books, idle Active/Level1/Level2/Level3/OS, x1/x5/x20, hitboxes, state/idle/animation labels, snapshot frame/graph/node/local time, last transition reason і playback generation. Override не зберігається; OS повертає native polling. Override керує відпочинком і поверненням до пригод, але activity statistics завжди класифікуються за реальною native activity. Debug tools не входять у release Quick Menu.

Settings має окремі sliders Background opacity, Road opacity та Overall opacity (0–100%). Загальна прозорість множить прозорість персонажів, ефектів, HUD, фону й дороги. Шкала HP, індикатор Stage/Wave та числа damage/rewards додатково успадковують Background opacity: при 0% фону вони приховані. Кнопка меню відкриває головну панель; Settings доступні з неї. Усі панелі меню залишаються непрозорими й інтерактивними за будь-якої прозорості гри, включно з 0%, щоб можна було повернути видимість. Прихований герой пропускає кліки на desktop також у native layer. Значення зберігаються після завершення перетягування; старі сейви використовують 100%, а Reset повертає всі три значення до 100%.

Ґрунтова доріжка `assets/environment/road_dirt_01.png` має прозорі краї та відображається вузькою смугою під персонажами поверх ландшафту. Її offset, як і offset фону, залежить від `GameSimulation.distance`, тому обидва рухаються та зупиняються разом.

Sound preference зберігається, але audio playback поки не реалізовано. Launch at startup — видимий disabled placeholder. `flame_audio` буде додано пізніше.

## Перевірка та відомі межі

- Етап 5 анімацій (2026-10-09): legacy player, adapters, presentation aliases,
  string-prefix fallback і compatibility fixtures видалені. Suite скорочено
  до критичних regressions. Актуальні результати перевірок наведено в
  [статусі міграції](docs/animation_architecture_plan.md).

- `flutter analyze --no-pub`: без issues (2026-10-08).
- Попередня повна перевірка `flutter test --no-pub`: **72 tests passed**, включно зі stage scaling, HUD rollback, повторним farming Stage 10 → 9 → 10, save migration, no-assets Flame startup, hero walk/attack/death/guard asset loading, death sequence 2.2 s з фінальним кадром 1 s, damage на slash frame при звичайній та прискореній атаці, guard між ударами, Exit/retry/failure/reset collision, invalid saves, chronological combat timing, програмні зміни швидкості, death frame hold, idle graph validation та near-linear MAX.
- Після перегляду економіки та місячного темпу прогресу: **90 tests passed** у повному `flutter test --no-pub`, включно з 30-денною симуляцією та новими idle assets. Global analyzer без issues; pixel regression перевіряє незмінність завершеної пози сидіння протягом паузи. Event simulation перевіряє баланс за 8 і 24 активні години на день; тривалий ручний playtest не проводився.
- Після фіксації attack speed та зменшення критів: **95 tests passed** у повному `flutter test --no-pub`; `dart analyze lib test tool` і `git diff --check` без issues. Перевірено старі speed/boots levels, кроки +0.1 п.п. / +0.01×, cap 80%, UI previews x1/x10/MAX і відповідність preview фактичній покупці на ширині 400 px. 30-денні scenarios оновлені; новий macOS build/live runtime для цих змін ще не перевірено.
- Попередній macOS debug build: успішний для попередніх змін (2026-10-08). **Release build успішний**: `flutter build macos --release --no-pub`, app 20.8 MB, arm64. Поточні Release/Profile обирають одну native Flutter-supported architecture через Xcode settings (arm64e host → arm64, Intel → x86_64). На Xcode 27 штатний `lipo -verify_arch arm64 x86_64` fails despite both slices present; universal build потребує окремого сумісного tooling verification. Intel mapping написано, але Intel build на цьому Apple Silicon Mac не перевірено.
- macOS runtime: перевірено travel/combat/death/reward, панелі Statistics/Upgrades/Equipment/Settings/Debug, purchases, idle override та global idle reset після input у Finder без focus companion. Після Save & quit/restart збережений equipment level відновився; native Quit menu також завершив save handshake. У поточному **release runtime** перевірено Quick Menu без Debug Tools, equipment item effect, відновлення Weapon Lv 1 і Quick Menu **Exit**. Exit записав новий lastSaveTime і завершив app process; гра після перевірки закрита.
- Windows C++ implementation написано, але Windows build/runtime на macOS **не перевірено**. Потрібен Windows host для validation Win32 transparency, click-through, DPI/taskbar behavior і WM_CLOSE save handshake.
- Hot-plug кількох monitor, зміна resolution і Dock/taskbar position реалізовані через notifications/messages, але live display-topology matrix не перевірялась. Monitor picker не входить до MVP.
- macOS alpha та Windows binary transparency різняться; Windows per-pixel alpha compositing — описане вище обмеження.
- Final sprite sheets, production balancing, audio, auto-launch — наступні етапи.

[Checklist усіх 34 пунктів і pending platform matrix](docs/requirements_checklist.md).


Тести залишено тільки для критичних вузлів: арифметики валют, списання Gold/Books, незмінності активного знімка проходження, одноразових нагород, бойових ударів та надійного збереження/відновлення прогресу. Правила додавання тестів: [AGENTS.md](AGENTS.md).

API references: [FlameGame](https://docs.flame-engine.org/latest/flame/game.html), [Flame image/animation API](https://docs.flame-engine.org/latest/flame/rendering/images.html), [Flutter macOS controller](https://api.flutter.dev/macos-embedder/interface_flutter_view_controller.html), [Apple idle timestamps](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)), [Win32 GetLastInputInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getlastinputinfo).
