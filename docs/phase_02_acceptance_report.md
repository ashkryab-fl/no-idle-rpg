# Етап 2: валюти та криві спорядження — приймання

Дата: 11.10.2026. [Вимоги](phase_02_currencies_and_equipment_curves.md), [загальний план](balance_refactoring_plan_v2.md).

Технічний етап реалізовано. Gold купує рівно Weapon/Armor/Helmet/Amulet, Books не купують характеристики. Спільний профіль `phase02_candidate_v1`, equipment-only domain command, partial x10/MAX, preview та save v8 інтегровані. Стартову стіну долають звичайні покупки й природні бої. Продуктове застосування Books, калібрування цін/ворогів і фінальне приймання V2 залишаються наступними етапами.

## Контракт і параметри

`EquipmentCurveProfile` — immutable core config з окремими Weapon/Armor parameters. `CharacterStats.calculate` обчислює CombatStats; runtime, UI і runner використовують його. Definitions містять зареєстровані ID/stat/price, а не власний effect. `EquipmentPurchases` приймає ID, перевіряє currency/count/wallet/effect і повторно рахує quote перед списанням. Arbitrary definition і bool wallet switch більше не є purchase API.

| Величина | Значення кандидата |
| --- | --- |
| База | HP 120, damage 14, APS 1, chance .05, multiplier 1.5 |
| Weapon/Armor | E=n до N=100; далі N+.5x+100 ln(1+x/200), окремі параметри N/W/r |
| Helmet | .05+.001n до n=200; потім .8−.55 exp(−(n−200)/550) |
| Amulet | 1.5+.01n до n=150; потім 3+2 ln(1+(n−150)/200) |
| Перші ціни Gold | Weapon/Armor 20, Helmet 35, Amulet 30 |
| Price growth | 1.1405, геометрична сума; не змінений для tuning |
| Вороги/нагороди | HP 1.08, damage 1.065, Gold/Books 1.10 за Stage; 5 хвиль |
| Books | Старий random per-kill drop, default chance .28; booksSpent=0 |
| Save | v8; v1–v7 несумісні, без конвертації старої сили |

HP/damage обчислюються через finite log10 Amount із fractional E. `StableMath` забезпечує expm1/log1p і ULP. Для effect guard використано спадну аналітичну marginal delta та неспадну precision spacing: один ULP відповідної величини, для Helmet — ULP біля .8. Це **консервативна числова межа**, а не пошук останнього випадкового ненульового subtraction double: після межі можуть існувати окремі округлені прирости, перемежовані plateau. Production не продає цей нестабільний хвіст. Додаткова перевірка фактично представленого CombatStat перед списанням обов'язкова. Продуктового epsilon немає.

MAX має closed-form affordability та ≤53 probes guard; технічний rank/count ≤2^53−1. Фінансовий rounding allowance обмежено 8 ULP логарифма ціни/wallet, щоб він не розростався до багатьох порядків ціни. Тести окремо відсікають wallet у 10 разів менший за ціну при rank 10^14.

Helmet guard: останній гарантовано корисний rank 16606; явна diagnostic policy epsilon=1e−6 обмежує його rank 3999. У поведінковому baseline жодна стратегія не досягає цих меж. Partial x10 за три останні корисні ранги сплачує тільки три. UI показує малий gain навіть для `80.00% → 80.00%`; display rounding не керує покупкою.

Живому герою Armor додає actual deltaMaxHp до нового cap. Інші предмети не лікують, мертвий герой чекає respawn. Current save з character `upgrades`, навіть порожнім, потребує valid current backup або повертає помилку. Future/corrupt preservation та serialized writes збережені. Меню Character Upgrades видалено; Books показуються у Statistics.

## Метод і відтворення

Код є незакоміченим working tree поверх HEAD `a0bd052f69ea7aea456debed30dc081507c036ee`. Точний source fingerprint, per-file SHA256, SDK, hardware та artifact hashes — [phase_02_source_metadata.json](balance/phase_02_source_metadata.json). Архів [phase_02_previous_source.tar.gz](balance/phase_02_previous_source.tar.gz) фіксує попередній робочий етап 1 з обома stat-джерелами; [його metadata](balance/phase_02_previous_metadata.json) перевіряється helper-скриптом. Відтворений JSON **точно збігся** з [попереднім baseline](balance/phase_02_previous_baseline.json). Поточний production не містить legacy mode.

[Повний baseline](balance/phase_02_baseline.json): seeds 1–20, 49 конфігурацій, 5880 checkpoint rows, 294 summary rows, P5/P50/P90/P95/min/max. Checkpoints .5/1/3/7/49/210 productive hours; 7 годин/день, day 7=49h, day 30=210h. Continuous run без restart/rest/offline rewards. Це productive-time модель; вона не передбачає стільки ж боїв за реальні 7 open hours із простоєм. Gold/productive hour = earned/hour; open time дорівнює productive time тільки в цих прогонах.

TTK — combat time до lethal hit **успішних** боїв, без travel/death/reward. Normal/boss windows — останні 200 victories кожного типу окремо. Deaths/100 — останні 200 усіх encounter outcomes. First-entry duration — останні 20 проходжень нових Stage, включно з farming/death між first entries; це не TTK п'яти поспіль виграних хвиль. Raw rows зберігають усі first-entry timestamps, HP, damage received, Armor recovery, respawn count, equipment ranks, spending, nextCost, marginal DPS/HP per Gold і recent-income affordability.

Adaptive policy перевіряє Armor у survival-контексті наступного ворога; далі обирає найбільший expected DPS gain/Gold серед Weapon/Helmet/Amulet. HP і DPS не порівнюються як одна одиниця. До 16 одиночних покупок між encounter, без cadence delay. Це прозора евристика, не оптимальний solver. Balanced shares — .375/.375/.15/.10, affordable/5-minute/hourly; omit policies нормалізують решту часток, focus купує один item.

[Purchase diagnostics](balance/phase_02_purchase_diagnostics.json) обчислює в кожному checkpoint ціну й приблизний час пакета Weapon, що зменшує `ceil(nextFoeHP/damage)` на один, та Armor-пакета для покриття expected incoming damage. Dead hero оцінюється після respawn. Null time означає відсутній дохід/representable target. Це counterfactual ordinary-hit estimate, не гарантований stochastic TTK або наступне рішення policy. Якщо пакет уже доступний, estimate=0, навіть коли balanced policy резервує Gold для інших items.

Команди з кореня репозиторію:

```sh
cd /Users/artemshkryab/dev/proj/idle_companion
mkdir -p build/phase_02
dart analyze lib test tool
flutter test --no-pub
dart run tool/balance/phase_02_audit.dart 20 > docs/balance/phase_02_baseline.json
dart run tool/balance/phase_02_curve_audit.dart > docs/balance/phase_02_curves.json
dart run tool/balance/phase_02_trace.dart > docs/balance/phase_02_controlled_traces.json
dart run tool/balance/phase_02_purchase_diagnostics.dart > docs/balance/phase_02_purchase_diagnostics.json
python3 tool/balance/reproduce_phase_02_previous.py > build/phase_02/previous_reproduced.json
git diff --check
```

`balance_audit.dart` і `simulate_progression.dart` тепер оцінюють активний equipment-only profile. Старі числа відтворюються через archive helper, а не цими current commands.

## Ізольовані зміни та прохідність

Однакові seeds, вороги, ціни й hourly cadence:

| Профіль | Highest Stage P50, 7h | Highest Stage P50, 210h |
| --- | ---: | ---: |
| Етап 1, Gold+Books stats | 93 | 710 |
| Gold-only, старі value curves | 29 | 73 |
| Chance soft-cap only | 29 | 73 |
| +Multiplier curve | 29 | 73 |
| +Weapon curve, стара Armor | 29 | 73 |
| +Armor curve, старий Weapon | 29 | 73 |
| Повний кандидат | 29 | 73 |

Найбільша втрата темпу походить від видалення Books-джерела. Рівність rounded Stage не означає рівність всіх значень: raw logs зберігають відмінності. Типові crit ranks нижчі порогів 200/150; ранги Weapon/Armor лише торкаються N=100 до day 30. Чутливості crit-tail/epsilon ще не тестують їхню пізню продуктовість.

| Candidate policy | 30m P5/P50/P95 | 7h P5/P50/P95 | 210h P5/P50/P95 |
| --- | --- | --- | --- |
| Adaptive | 7 / 8 / 8 | 29.95 / 30 / 30 | 69 / 69 / 69.05 |
| Balanced affordable | 9 / 10 / 10 | 33 / 33 / 34 | 72.95 / 73 / 73.05 |
| No purchases | 2 / 2 / 2 | 2 / 2 / 2 | 2 / 2 / 2 |

Природний no-crit Stage 1: 20 hero hits, 15 enemy hits, 5 rewards, HP 28.2. Runtime і event model узгоджені на attack/death boundaries. [Seed-1 early trace](balance/phase_02_controlled_traces.json) досягає Stage 8 за 30m: перший Weapon на 26.54s, Armor на 80.92s, далі всі чотири items; 40 транзакцій, Weapon13/Armor9/Helmet8/Amulet10. Positive HP має тільки initial/Armor purchase/respawn. Усі 20 adaptive seeds долають першу стіну. Hourly/no-purchase раннє farming Stage 1–2 є наслідком затримки/відсутності покупок, а не доведеним незворотним blocker.

Adaptive 7h: median normal/boss TTK 3.35/3.35s, deaths/100=10.5; 210h: 4.35/4.35s, deaths/100=11.0. На 210h P95 між seed для normal/boss P50 — 5.35s; медіана recent first-entry duration 25504.86s (7.08h), що показує сильне уповільнення відкриття нових Stage попри короткі успішні бої. Balanced day-30 boss TTK 5.35s, deaths/100=11.5, first-entry duration 26249.20s. Короткий TTK сам по собі не підтверджує прийнятний late progression.

Adaptive ranks у .5/7/210h: (14,9,8,10)/(43,42,38,40)/(96,96,91,93), порядок Weapon/Armor/Helmet/Amulet. Median spend shares змінюються з 34.49/15.23/22.34/27.45% до приблизно 25.52/25.52/23.15/25.81%. Суми медіан часток не зобов'язані дорівнювати 100%. До day 30 earned Gold=170.91M, spent=168.88M, remaining=2.03M; booksSpent=0. Наступний Weapon коштує приблизно 2.39h поточного farming income; пакет для скорочення ordinary-hit count — медіанно 2 ranks і 6.95h. Оцінка доходу не прогнозує майбутню швидкість після покупки.

Balanced affordable досягає Stage 73; Weapon-only 42, Armor-only 26, Helmet-only/Amulet-only 2, omit Weapon 25, omit Armor 38, omit Helmet/Amulet 72. На 7h omit Helmet дає Stage 35 проти balanced 33, omit Amulet — 34. Отже, ранні crit items за цими цінами можуть поступатися іншим витратам. Жодний перевірений one-item focus не домінує всюди; це не доказ відсутності всіх оптимізованих hyperfocus builds.

## Корисні контексти, stress і числові межі

У crafted paired seeds 1–20 на Stage 25, 900 productive seconds, базовий Weapon30/Armor60; для Helmet — Amulet150, для Amulet — Helmet500. Порівнюється одна покупка до бою, подальшого reinvestment немає:

| Покупка | Природний ефект |
| --- | --- |
| Weapon +10 | First-fight TTK P50 5.35→3.35s; менше ударів у 20/20 seed; 900s kills 54→62 |
| Armor +10 | First-fight HP P50 2132.71→3542.38; deaths за 900s 4→2, highest Stage 31→33 |
| Helmet +50 при Amulet150 | Expected DPS +9.09%; first-fight TTK P50 5.35→4.35s; менше ударів у 5/20 seed |
| Amulet +20 при Helmet500 | Expected DPS +7.76%; first-fight TTK зменшився у 5/20 seed; P50 лишився 4.35s |

Ці контексти доводять реальний discrete/survival effect, але не типовість такого crit build за поточними цінами. Потрібно підсилити ранню цінність crit у майбутньому tuning, а не робити висновок з однакових rounded medians.

Typed stress inputs живуть тільки в harness. Stage/first-clear bonus — частка **базової boss kill Gold**; stage bonus на кожний boss clear, first-clear лише раз на Stage. Це proxy source-specific reward, а не ціна/ефект реалізованого таланта. Kill multiplier застосовано один раз, travel змінює encounter distance/time без повторного множення reward. Tests при вимкнених purchases перевіряють тотожні kills/stage для Gold bonus, незмінні Books та точну суму stage-scaled rewards при швидшому travel.

| Adaptive income input | Stage P50, 210h | Gold earned P50 | Транзакції P50 |
| --- | ---: | ---: | ---: |
| Current | 69 | 170.91M | 376 |
| All kills +25/+50/+75% | 72 / 74 / 75 | 270.09 / 392.11 / 537.38M | 390 / 401 / 411 |
| Stage-source +25/+50/+75% | 69 / 70 / 70 | 181.34 / 192.57 / 203.79M | 378 / 379.5 / 381 |
| First-clear source +25/+50/+75% | 69 / 69 / 69 | 171.00 / 171.07 / 171.15M | 376 / 376 / 376 |
| Travel ×.75 / ×.5 | 70 / 71 | 198.68 / 233.95M | 380 / 385 |

Більший Gold вже реінвестовано, тому приріст earned не дорівнює механічному multiplier: швидші бої/вищі Stage змінюють потік доходу. First-clear proxy майже не впливає на повторний farming — важливий ризик для pricing/альтернатив талантів.

Sensitivity: amulet threshold ×2.5/×3/×4, short/long logarithmic tail, N50/N100/N200, W100/W200/W400, r=.5/.75, epsilon=1e−6. Adaptive N50 дає Stage 67 на day 30 проти 69; решта мають Stage P50=69. Повна N/W/r сітка, включно з r=1, перевірена синтетично; behavioral runs навмисно ізолюють відібрані зміни. Доказ цінності tail після його фактичного досягнення лишається для розширеного V2 tuning.

[Curve/precision audit](balance/phase_02_curves.json): finite logs для 1M ranks; усі behavioral zero-effect rejection counters=0, synthetic boundary requests відхиляються без списання. MAX на 1M доступних Weapon ranks: 1000 samples після 10 warmups, Mac14,2 / Apple M2 / 8 cores, Dart 3.12.0 arm64, P50=6µs, P95=40µs, max=375µs. Виміряний локальний бюджет 1ms/operation витримано; це не універсальна гарантія для інших пристроїв. Замір включає quote+purchase, виконаний паралельно з CLI audit, без desktop preview.

## A01–A14 та перевірки

| ID | Статус і доказ |
| --- | --- |
| A01 | PASS: baseline stats/history/wallet invariants; рівно 4 IDs; semantic search без Books stat catalog/map/API/active XP |
| A02 | PASS: registered ID, currency, negative/zero/extreme counts, Gold-only debit; failure no-mutation |
| A03 | PASS: Helmet 0/199/200/201/500/1000; рівно 25% на 200; strict diminishing gains у робочому діапазоні |
| A04 | PASS: multiplier threshold/tail, Power N/W/r grid, fractional E і finite logarithms |
| A05 | PASS із явною conservative precision policy: guard bounds, final actual effect, no plateau debit, million-rank benchmark, huge-price tolerance |
| A06 | PASS: single/bulk threshold crossing/cost, partial money/effect count, stale wallet/rank recheck; widget preview і tiny gain |
| A07 | PASS: природний Stage 1, actual Armor delta до/після N, no other-item healing/dead revival; rest/suspend інваріанти етапу 1 |
| A08 | PASS: v8 roundtrip/reset/restart, v1–v7 boundary, primary/backup combinations, future/corrupt preservation, forbidden current upgrades; navigation widget test |
| A09 | PASS: runtime/event hit/HP/reward/stage parity, curved crit build; Gold-only transactions, booksSpent=0, death-boundary checkpoint parity |
| A10 | PASS: exact previous reproduction, isolated profiles, 20 seed, policies/quantiles/time units/raw logs/metadata |
| A11 | PASS для перевіреної ранньої моделі: adaptive виходить зі Stage 1–2 farming; жодного недослідженого раннього blocker не знайдено; late slowing явно зафіксовано |
| A12 | PASS для технічного етапу: усі items мають natural/crafted ефект; ранні crit prices та універсальна конкурентність ще не прийняті як фінальний баланс |
| A13 | PASS: окремі kill/stage/first-clear/travel inputs, actual reinvestment, no-double-count tests; не доказ домінування/окупності реального таланта |
| A14 | PASS: технічний проміжний стан відділено від release/KPI; Books застосування й фінальний баланс pending наступних фаз |

`dart analyze lib test tool`: **No issues found**. `git diff --check`: чисто. Full `flutter test --no-pub`: **128 passed, 2 failed**. Обидві помилки вже існували до етапу 2 й стосуються відсутніх authoring inputs:

- `test/game/animation_content_test.dart`: `tool/sprite_assets/manifests/hero/sharpen_v1.json`.
- `test/game/goblin_animation_test.dart`: `art/enemy/gobli_low/manifest.json`.

Нові curve/purchase/price/parity/persistence/UI сценарії проходять; відсутні manifests не відновлювались вигаданими файлами. Desktop build/live input/rest/restart і native rendering цієї зміни не запускались. Widget/headless tests не замінюють desktop smoke. Windows build/runtime не перевірені.

## Передача наступним етапам

1. Етап 3: реальні Books prices/rewards/choice та шість талантів; повторити source-specific stress із реальними альтернативами й 8 active combinations.
2. Етап 4: розширення quote/save для talent state та спеціалізації; current equipment guard не обходити generic command.
3. Етап 5: розглянути ранні Helmet/Amulet prices/growth разом із crit synergy; зменшити day-30 first-entry durations, перевірити mixed/focus/omit states, duty/rest та пороги soft-cap, яких typical baseline ще не досяг.

День-30 успішний TTK тут близький до 3–15s, але тривалість відкриття Stage вимірюється годинами. Це не приймання загального V2 KPI. Дані не доводять відсутності домінування майбутнього Gold-таланта чи достатньої користі кожного предмета в усіх типових фазах.
