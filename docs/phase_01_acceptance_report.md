# Етап 1: реалізація й перевірка видалення рівнів героя

Дата: 11.10.2026. Специфікація: [phase_01_remove_hero_levels.md](phase_01_remove_hero_levels.md).

Код першого етапу реалізовано: character level/XP, XP-нагороди, формули росту та level-up healing видалені з domain, runtime, UI, save й balance tools. Числові параметри ворогів, ціни, обидва Gold/Books stat-каталоги й порядок бойових подій збережені. Рефакторинг має синтетичні докази; формальне desktop-приймання A11 ще потребує smoke check у запущеному застосунку.

## Зміни поведінки

- Без покупок: max HP 120, damage 14, APS 1, crit 5%, multiplier ×1,5, expected DPS 14,35. Перемоги, валюта, Stage, kills і час не множать силу.
- Enemy death animation завершується перед єдиним нарахуванням Gold/Books. Завершення звичайної чи boss wave не лікує.
- HP-покупка живому герою відновлює фактичний приріст max HP, з обмеженням новим max HP. Damage/crit та невдала покупка не лікують; мертвий лишається з нульовим HP до respawn. Controller делегує це правило `GameSimulation.upgrade`.
- Смерть відкочує Stage на один, мінімум до 1, обнуляє wave progression та зберігає валюти/покупки/kills. Respawn лікує штатно.
- Stage/Wave, рівні покупок, IdleLevel, rest і suspend policy залишаються.
- Statistics/Debug/reset/preview більше не використовують рівень героя. Preview рахується через `CharacterStats.calculate`.

## Persistence

Схема v7 несумісна з v1–v6. `SaveMigrator` видалений. `load`, `save` і `reset` працюють в одній serialized queue; write snapshot захоплюється синхронно, temp flush/rename та актуальний backup збережені.

Відомий legacy primary не блокує актуальний backup. Коли є лише v1–v6, вони очищаються і startup отримує нову гру. Пошкоджений current primary відновлюється лише з читабельного current backup. Якщо актуального backup немає, corruption не перетворюється на silent reset. JSON без читабельної версії також є помилкою. Невідома schema у primary або backup блокує автоматичне завантаження й запис. Explicit Reset у чинному recovery UI лишається доступним.

Зайві `character.level`/`character.xp` у v7 не читаються й не емітуються. Current HP та незавершений combat не входять до сейву: повторний запуск починається з max HP. Це чинний restart-healing ризик, не повернення level-up healing. Реальні application-support сейви під час реалізації не відкривались і не очищались; persistence-тести використовують тимчасові каталоги.

## Детерміновані докази

`test/game/phase_01_test.dart` підтверджує природне проходження Stage 1 без crit і покупок: 20 ударів героя, 12 звичайних ударів ворогів по 6 і 3 boss удари по 6,6. Після п'ятої перемоги: Stage 2/Wave 1, HP 28,2/120; max HP і damage не змінились. Ворог після смертельного удару не відповідає.

Інші fixtures перевіряють HP 50 → 56 після Armor 1 (max HP 120 → 126), невдалу покупку, Weapon/crit без лікування, покупку під час смерті, reward boundary, rollback на Stage 10 та Stage 1, rest/suspend. `enemy_progression_test.dart` перевіряє повторний цикл 10 → 9 → 10 без росту CombatStats.

`event_simulation_parity_test.dart` порівнює runtime і event model на no-crit kill, crit kill, смерті, boss clear та HP-покупці. Для контрольованих encounter використовується однаковий сталий random roll, а не припущення, що seed сам по собі забезпечує однакове споживання RNG. Збігаються порядок/напрямки ударів, crit flags, суми, результат, нагороди, Stage/Wave та HP. Перевірки Amount: log-похибка ≤1e−10, HP у цих невеликих fixtures — абсолютна похибка ≤1e−9. Час удару відрізняється не більше одного fixed tick (1/60 s); completed death boundary — не більше двох ticks. Після смерті окремо перевірено штатний respawn і його HP-журнал.

Runner зберігає pending події між checkpoints. Reward приходить після enemy death, а `rewardPending` скидається саме при підтвердженні. Щосекундні checkpoints і один безперервний прогін дають однаковий snapshot за контрольного seed. Журнал позитивного HP містить лише `initial`, `hpPurchase`, `respawn`.

[Сирі керовані traces](balance/phase_01_controlled_traces.json) містять удари, час, HP і причини відновлення. Початковий пошкоджений HP та wallet 20 у purchase-сценарії — явно заскриптовані fixtures.

## Новий baseline

[Raw data і summaries](balance/phase_01_baseline.json): seed 1–20, шість стратегій, checkpoints 0,5 / 1 / 3 / 7 / 49 / 210 productive hours. День 1/7/30 означає відповідно 7/49/210 productive hours, без rest, offline rewards і restart. Це верхня модель продуктивності, не вимір реальних open hours.

Balanced policy розподіляє наявний на початку покупки бюджет кожної валюти: 37,5% damage, 37,5% HP, 15% crit, 10% multiplier. `affordable_balanced` перевіряє доступність цих часток між кожними encounter; інші cadence — 5 хв та година. Focus-політики витрачають 100% Gold і Books на відповідний damage/HP stat. Вони не є Gold-only стратегіями фінальної V2. Покупки пакетні; `successfulPurchases` рахує успішні операції для конкретної definition, не суму придбаних рівнів.

| Policy | Highest Stage P50, 30 хв | 7 год | 210 год | Normal TTK P50 на 210 год, с | Boss TTK P50, с |
| --- | ---: | ---: | ---: | ---: | ---: |
| No purchases | 2 | 2 | 2 | 3,35 | 3,35 |
| Affordable balanced | 16 | 176 | 727 | 154,35 | 146,35 |
| Кожні 5 хв, balanced | 12,5 | 167 | 726 | 152,35 | 144,35 |
| Щогодини, balanced | 2 | 93 | 710 | 137,85 | 130,35 |
| Damage only | 13 | 89 | 298 | 0,35 | 0,35 |
| HP only | 11 | 30 | 50,5 | 140,85 | 137,35 |

TTK — медіана між seed від внутрішніх window medians; зберігаються також P90. Окремі останні 200 зразків використовуються для normal/boss victories, encounter HP/deaths та purchase intervals; перші проходження — останні 20. TTK не містить програні бої, тому focus на damage має короткі перемоги поруч із частими смертями. Вікно не дорівнює фіксованій останній годині й ранні значення можуть містити менше 200 зразків.

Summary дає P50/P90/P95/min/max між seed для числових метрик, доходів/залишків та HP-healing. Raw Amount зберігаються у log10-space, нуль — `null`; summary переводить величини у `double` (поточний профіль не досягає його overflow). Raw rows також містять придбані рівні, first-stage-entry times, HP-покупки й respawn counts. Purchase wait — інтервал між успішними інвестиціями; нуль без покупок означає відсутність зразків.

Рання незворотна стіна не підтвердилась: усі 20 affordable seed мають покупки HP, виходять за Stage 2 за 30 хв і збільшують highest Stage між 30 хв та 7 год. No-purchase лишається біля Stage 1–2, продовжує заробляти Gold/Books та не набуває сили. Погодинна стратегія має таку саму першу півгодини через відкладені покупки; це cadence, а не відсутність доступного фарму.

Пізній TTK 130–154 с не відповідає фінальним KPI V2. Ціни/вороги в цьому етапі не підлаштовувались. Дані є входом у наступні етапи з розведенням валют, кривими, талантами й tuning.

## Історичне порівняння

[Старий raw report](balance/phase_01_legacy_baseline.json), [metadata](balance/phase_01_legacy_metadata.json) та [архів коду](balance/phase_01_legacy_source.tar.gz) зафіксовані до правок першого етапу. Архів містить тодішній working tree разом із наявними незакоміченими змінами; один лише HEAD не відтворює цю основу. Production не має legacy режиму.

| Hourly balanced, 7 productive hours/day | День 1 | День 7 | День 30 |
| --- | ---: | ---: | ---: |
| Старий highest Stage P50 | 181,5 | 1961 | 4873 |
| Новий highest Stage P50 | 93 | 447 | 710 |
| Старі deaths P50 | 117 | 132 | 132 |
| Нові deaths P50 | 172,5 | 750 | 1417 |

Значення дня 7 у цій таблиці беруться з 49-годинного checkpoint. Old/new одночасно прибирає і growth, і healing; окремого чотирирежимного причинного harness немає. Старий runner також мав раннє нарахування reward/checkpoint overshoot; новий узгодив death boundary і pending events. Тому таблиця показує масштаб змін, а не чисту ізольовану оцінку кожної причини. Поточний baseline не видається за остаточний місячний баланс.

## Приймання

| ID | Статус і доказ |
| --- | --- |
| A01 | Виконано: semantic search production/domain/UI/tools без XP API/coefficients; analyzer без issues |
| A02 | Виконано: базові формули, однакові покупки → ті самі stats; no-purchase farming не дає сили |
| A03 | Виконано: reward/HP/death fixtures та журнал initial/purchase/respawn |
| A04 | Виконано: природний Stage 1, один reward після death, boss/rollback/respawn/farming |
| A05 | Виконано: domain MAX/partial x10, widget preview і фактичні x1/x10/MAX, controller HP-покупка |
| A06 | Виконано синтетично: rest/suspend та наявні idle/rest/coordinator тести |
| A07 | Виконано: persistence matrix v1–v6/v7/future, corrupt backup, snapshot/queue/reset/save-before-quit |
| A08 | Виконано на керованих encounter: удари/crit/reward/HP/stage parity та checkpoint invariance |
| A09 | Виконано: raw 20-seed data, policies/time units, source fingerprints і відтворений old baseline |
| A10 | Виконано для коротких контрольних сценаріїв: природний Stage 1 та 20 affordable seed без доведеного раннього blocker |
| A11 | Частково: widget tests при 400×620 пройшли; desktop smoke check не запускався |
| A12 | Виконано: README й цей звіт розрізняють правила, baseline, ризики та неперевірене |

Повний `flutter test`: 111 пройдених тестів і два сторонні failures через відсутні packing manifests: `tool/sprite_assets/manifests/hero/sharpen_v1.json` і `art/enemy/gobli_low/manifest.json`. Ці тести анімацій і assets не виправлялись у межах balance-етапу. Цільовий набір domain/runtime/persistence/app/presentation: 61 тест пройшов. GUI build, фізичний desktop smoke, native input timing і Windows runtime не перевірялись.

## Відтворення

З кореня `/Users/artemshkryab/dev/proj/idle_companion`, з поточним Flutter/Dart та встановленими залежностями:

```sh
cd /Users/artemshkryab/dev/proj/idle_companion
mkdir -p build/phase_01
flutter analyze
flutter test test/core/persistence_test.dart test/domain/progression_test.dart test/game/phase_01_test.dart test/game/event_simulation_parity_test.dart test/game/progression_pacing_test.dart test/game/enemy_progression_test.dart test/game/economy_balance_test.dart test/game/simulation_test.dart test/app test/presentation

dart --packages=.dart_tool/package_config.json tool/balance/balance_audit.dart 20 > build/phase_01/audit.json
dart --packages=.dart_tool/package_config.json tool/balance/phase_01_trace.dart > build/phase_01/traces.json
python3 tool/balance/reproduce_phase_01_legacy.py > build/phase_01/legacy.json
```

[phase_01_source_metadata.json](balance/phase_01_source_metadata.json) поряд із baseline містить поточний HEAD, source SHA256 і checksum звітів. Legacy reproduction звіряє архівні fingerprints та використовує окремий package root під `build/`. Його JSON відтворив початковий old report точно. New baseline повторно дав ті самі raw rows; recovery callbacks не змінюють RNG або правила.
