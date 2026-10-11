# Етап 3: таланти та джерела Books — приймання

Дата: 11.10.2026. [Специфікація](phase_03_talents_and_books_sources.md), [загальний план](balance_refactoring_plan_v2.md).

Реалізовано шість талантів, три пари альтернатив, Books-покупки, відкладений вибір, незмінний snapshot спроби, контекстні ефекти, finite Books і збереження HP/claims. Runtime та event runner використовують спільні `TalentPurchases`, `StageAttempt`, `CombatSystem.calculate` і `StageSettlement`. Кандидат — `phase03_candidate_v1`; equipment та enemy coefficients етапу 2 збережено. Enemy crit не підвищувався для виправдання захисної гілки.

Це приймання механік та початкового кандидата. Остаточна конкурентність усіх стратегій і KPI дня 30 не доведені. First-clear Gold має локальні вигідні продовження, але слабкий глобальний сигнал; protection має природні випадки запобігання летальному удару, але не значущий загальний frontier gain на 20 seeds. Ці межі наведено нижче, разом із результатами, які їх показали.

## Реалізований контракт

| Правило | Значення |
| --- | --- |
| Пара boss | `boss_damage` / `first_clear_gold`, first clear Stage 1 |
| Пара endurance | `stage_heal` / `crit_protection`, first clear Stage 3 |
| Пара travel | `shorter_travel` / `stage_gold`, first clear Stage 5 |
| Rank gates | 1–3 спочатку, 4–6 після first clear 20, 7–10 після 100; rollback не закриває gates |
| Ціна | `3×1.6^n Books`; 10 рангів однієї гілки ≈544.755814; всі шість ≈3268.534883 |
| Ефект | `B×(1−exp(−n/3))/(1−exp(−10/3))`; rank 0=0, rank 10 точно B |
| B | boss .5; first-clear .5; heal .2; protection .6; travel .25; stage Gold .5 |
| Books | first clear 3; два наступні clear по 1; потім 0 |
| Milestones | 5/10/20/40/60/80… по 5 Books один раз; Stage 20 не дублюється |
| First-clear Gold | окрема nominal boss Gold база для всіх build; бонус лише до цієї бази |
| Stage Gold | частка суми п’яти nominal kill Gold з незмінного плану; first clear і два повтори |
| Kill Gold | звичайна нагорода кожної перемоги, незалежна від first-clear/stage bonuses |
| Лікування | тільки alive full-stage settlement; current max HP × snapshot fraction, cap missing HP |

Купівля змінює owned rank, списує Books і не обирає талант/не лікує. Selection безкоштовна; допускає один ID або none на пару. x10/MAX показують фактичну кількість і ціну, обмежені wallet/gate/cap/позитивним ефектом. Domain перевіряє ID/count/pair/owned rank; невдала покупка нічого не списує. Для числово насиченої кривої MAX зупиняється перед plateau.

Snapshot створюється перед першим продуктивним travel, а не під rest або під час відкриття меню. Він містить attempt ID, stage, profile ID, selected ranks, фактичні effects і п’ять enemy IDs/distances/nominal rewards. Mid-attempt rank/selection змінюють наступну спробу. Equipment лишається live. Clear/death закриває спробу; rest/suspend/restart її зберігають. Selection у reward hold або після clear під rest може увійти в наступний snapshot.

Boss bonus застосовується після hero crit тільки до boss hit. Protection зменшує лише `D×(M−1)` enemy crit bonus; noncrit/chance/APS незмінні. Travel скорочує лише відстань до spawn. Reward/approach/attack/death/respawn/rest timing не прискорюються.

`StageSettlement` синхронно оновлює wallet, first-clear frontier, saturated repeat ledger і cursor `(attemptId,wave)`. Runtime синхронно застосовує HP/counters/stage і лише потім створює UI reward. Покинута через смерть спроба закриває cursor terminal wave=5, без completion/claim/reward; її запізнілі events ігноруються навіть до першого settlement нової спроби. Wave/attempt для settlement захоплено при spawn: повторний завершений death callback не може оплатити наступну хвилю або створити другий UI reward. Milestone claims однозначно виводяться з frontier, оскільки first clears послідовні й виплата входить до того самого settlement.

## Сейв і restart

Schema **v9**. Відомі дорелізні **v1–v8 несумісні та відкидаються** за узгодженим попереднім правилом; legacy primary не блокує валідний current backup. Поточні й майбутні пошкоджені/невідомі states не маскуються під legacy. Реальні application-support сейви під час цієї роботи не читались і не очищались; repository/recovery перевірено в temporary directories.

Capture копіює character/activity/settings синхронно, а active snapshot/reward immutable. Зберігаються HP, stage/wave, queued selection, active attempt або явний null boundary, cursor/claims/quota, travel remainder і фазовий checkpoint.

| Збережений стан | Наступна фактична дія після load |
| --- | --- |
| Travel | та сама спроба/wave, HP і travel remainder |
| Approach/combat | той самий запланований ворог/wave зі свіжим enemy HP і збереженим hero HP |
| Pending enemy death | смерть ворога відтворюється до settlement; reward один раз |
| Committed reward | відновлюється hold, без повторної оплати/лікування |
| Reward після full clear | `attempt=null`; новий snapshot тільки перед наступним продуктивним travel |
| Hero death/respawn | HP=0 до звичайного respawn; constructor не лікує |
| Невідомий talent profile | current backup або явна recovery error; saved effects не перераховуються |

Точне frame/RNG resume не реалізовано. Recovery може відкотити **весь** попередній checkpoint; захист від ручного редагування/підміни старого сейву не заявляється. Reset очищує ranks, selection, frontier, repeats, cursor і snapshot; смерть зберігає permanent history.

## Перевірки механік

`flutter test --no-pub`: **186 passed, 2 існуючі asset failures**. Обидва були присутні до етапу 3:

- `animation_content_test.dart`: відсутній `tool/sprite_assets/manifests/hero/sharpen_v1.json`.
- `goblin_animation_test.dart`: відсутній `art/enemy/gobli_low/manifest.json`.

`flutter analyze --no-pub` та `dart analyze lib test tool`: без issues; `git diff --check`: чисто. Нові domain/runtime/recovery/stream/widget tests проходять. Вони перевіряють finite криві, precision/currency/count guards, partial MAX, gates, всі 8 choices/null, immutable snapshot, delayed purchase/select, live equipment heal delta, source separation, milestones/repeat caps, duplicate settlement і callback, pending/committed restart, low/zero HP, rest/suspend, whole-checkpoint backup і reset.

[32 контрольні traces](balance/phase_03_controlled_traces.json): всі 8 selections × normal/boss × crit/noncrit. Збігаються hits, amounts, HP, Gold/Books і stage/wave. Допуск hit-time — один fixed step, повного travel→approach→settlement — чотири fixed steps. Окремо **20 seeded stream tests** зі спільними combat/travel/selection streams збігаються через перший settled stage. Combat rolls йдуть хронологічно та припиняються на lethal boundary; повторне читання damage iterable не переролює crit.

Widget-перевірка на 400×620 підтверджує доступність трьох пар, locked state, fractional ціни, незалежні Buy/Select, owned/current/next, partial count, exhausted stage reward і відсутність layout exceptions. **Manual desktop interaction, реальний input/rest, macOS/Windows build та фізичний runtime не перевірялися.** Це лишається етапу 7.

## Природні прогони

[Основна матриця](balance/phase_03_baseline.json.gz): 76 конфігурацій × 20 seeds × 6 checkpoints = **9120 rows**. Час: .5/1/3/7/49/210 productive hours. 49/210 — дні 7/30 за 7 productive hours/day, а не години відкритої програми.

Включено всі 8 реально оплачених комбінацій; всі 8 selection-only comparisons за однакових gated owned rank 3; no talents; шість isolated funded/matched effects; low/high B sensitivity кожного ефекту; Books first reward 2/3/5 і repeat limits 0/1/2; affordability/5-minute/hourly Books cadence; uniform/omit-one/focus; чотири equipment focus та balanced; wrong-first purchase без refund; actual rest duty 25/50/75%.

Gold policy у парних runs однакова. Matched rank 3 **надається для ізоляції selection і не є доказом funding**. Основна policy з назвою `adaptive` адаптує equipment покупки та купує Books за доступністю/рангом, але тримає fixed boss/heal/travel selection. Справжня contextual selection окремо перевірена [ще на 20 seeds](balance/phase_03_contextual_adaptive.json.gz): інвестує в усі шість, обирає economy для доступного прогресу, travel після exhausted quota, protection після crit death, heal в інших спробах. Journals містять фактичні Books-покупки й зміни selections. Це евристики, не оптимальний гравець.

`highestStage` у старому runner означає найвищий **відвіданий** stage. Новий `firstClearFrontier` — історично завершений frontier; у цих послідовних runs він рівно `highestStage−1`. `stage` показує поточний stage після rollback. Ці поля не підміняють одне одного.

Медіанний найвищий відвіданий Stage:

| Policy | .5 h | 1 h | 3 h | 7 h | 49 h | 210 h |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Нові rewards, no talents | 8 | 12 | 21 | 30 | 52 | 69 |
| Boss/heal/travel, оплачено | 9 | 13 | 25 | 34 | 57 | 73 |
| Boss/heal/stage Gold, оплачено | 9 | 14 | 25 | 34 | 56 | 73 |
| First Gold/heal/stage Gold, оплачено | 9 | 13 | 24 | 33 | 55 | 72 |
| Boss/protection/travel, оплачено | 9 | 13 | 23 | 32 | 54 | 71 |
| Uniform, усі шість | 8 | 13 | 24 | 33 | 55 | 70 |
| Wrong first → mixed, без refund | 9 | 14 | 25 | 34 | 57 | 73 |
| Contextual adaptive, усі шість | 9 | 13 | 24 | 34 | 56 | 73 |

Економіка не домінує на всіх горизонтах. Stage Gold виграє у ранньому investment контексті; boss/heal/travel та boss/heal/stage Gold мають найкращий перевірений довгий frontier. Глобальні P5/P50/P95, source totals, TTK, deaths, investments/gates, HP, crit, travel і ledger sizes збережено в raw reports. Наведені paired intervals — normal-approximation опис цих 20 seeds, не доказ оптимальності.

У fixed mixed policy на 210 h first+milestone Books дають median **63.57%** доходу (seeds 63.25–64.10%). Median earned ≈379.5 Books, spent ≈236.65824 на три branches rank 6; uniform витрачає ≈347.48736. Rank 7–10 gates не відкриті до дня 30: first clear 100 ще не досягнуто. Повного дерева за ранній час немає, але час до Stage 100 є tuning deviation для етапів 5–6.

Після finite repeat Books звичайний Gold продовжує давати фактичні equipment покупки й нові first clears. Wrong-first policy доходить до того самого median 73 без повернення перших 3 Books. Infinite Books/death farm не виникає: forced clear→death→restart шість разів дає Stage 1 сумарно 5 Books, а не шість нових first-clear виплат.

При 210 **open** hours і заданому duty 25/50/75% фактичний productive median ≈53.13/105.89/158.15 h. Rest починається після поточного encounter/reward, тому це не просте множення deadline на duty. Rest не проганяє events і не створює бонусів.

## Корисність альтернатив і межі

- **Boss damage:** rank-3 matched selection на 210 h дає mean frontier delta +.9, approximate interval [.77,1.03]; дискретні boss hits і HP підтверджені traces.
- **Stage recovery:** +1.9 [1.77,2.03] stages у тому самому matched comparison; фактичне healing окреме від Armor/respawn, ніколи не від purchase/select/restart.
- **Shorter travel:** +.8 [.62,.98] stages; скорочений лише pre-spawn відрізок. Користь слабшає за довгих боїв.
- **Stage Gold:** рання природна користь з реінвестицією: matched mean +.6 [.338,.862] stage на 1 h, +.95 [.726,1.174] на 3 h. На 210 h interval охоплює 0: quota saturation звужує контекст користі.
- **Crit protection:** [природний counterfactual audit](balance/phase_03_natural_crit.json), незмінні 3%/×1.5 enemies. За 7/49/210 h у 20 seeds — 35/231/981 негайно летальних hit averted; серед них boss hits 10/46/74. На 210 h 306 encounters завершилися перемогою після такого hit. Це той самий pre-hit HP і той самий rolled crit зі знятим protection, **не** альтернативна повна timeline. Загальний matched frontier delta +.05 [−.174,.274] не доводить сильний progress gain, але користь не обмежена crafted 100%-crit ворогом.
- **First-clear Gold:** rank 3 додає ≈5.46% доходу повного першого циклу за рівних nominal wave rewards, через окрему first-clear базу. Глобальний matched frontier signal на 210 h — 0 [−.201,.201]. [Парні продовження природного checkpoint після Stage 5](balance/phase_03_payback.json) витрачають однакові 15.48 Books, зберігають HP/Gold/equipment і записують фактичні equipment покупки. Gold-альтернатива швидше досягає Stage 8 у 8/20 continuations; наприклад seed 2 — 656.58 s проти 776.74 s. В середньому boss альтернатива сильніша. Це локальна користь й явний ризик слабкої загальної гілки, а не підтверджена однакова конкурентність.

Mixed й економічні alternatives досліджені з реальними цінами; швидкість оплат і реінвестиції не замінено scalar Gold/hour бонусом. Остаточний коридор приблизно 5% relevant gain вище seed noise для кожної гілки потребує наступного tuning. Зокрема first-clear Gold/protection не мають значущого загального frontier gain на цих horizons. На етапі 3 не змінювали enemy crit або reward base приховано, а зберегли природні контексти та negative findings для вибору профілю в етапах 5–6.

## Розмір і числова діагностика

[Криві та latency/ledger stress](balance/phase_03_domain_diagnostics.json): MAX bounded до 10 ranks; локальні quote timings ≈1–2.4 μs після warm-up, без cross-platform гарантій. Frontier 10¹² без repeats дає save 923 bytes; 100000 sparse saturated repeat entries — 989817 bytes, capture ≈35 ms, encode ≈29 ms на цій машині. У природному mixed run на день 30 talent ledger median 775 bytes. Немає масиву всіх first-clear/milestone IDs.

Travel/savings counters runner враховують запланований відрізок при його початку: checkpoint посеред останнього travel може включати ще не пройдений remainder. TTK — completed victories; recent windows — останні 200 outcomes. Повний phase-time decomposition/first-wall UX та точний frame/RNG restore не заявляються як завершені. Ledger/формули підтверджені окремо від таких telemetry вдосконалень.

## A01–A16

| ID | Стан / доказ |
| --- | --- |
| A01–A04 | Шість contextual effects, independent curves/prices, gates/caps/currencies; old per-kill Books API видалений |
| A05–A06 | Immutable attempt, queued selection/ranks, rest/death/clear ordering; all 8 controlled traces |
| A07–A08 | Finite repeats, monotonic frontier, milestone dedup, typed source bases, cursor та captured-wave duplicate guard |
| A09–A10 | Actual restart→settlement/recovery tests, low/zero HP, known/unknown schema/profile; fresh domain quote і no-debit guards |
| A11 | Shared resolver/settlement; 32 controlled traces і 20 independent seeded stream tests |
| A12 | Natural start і wrong-first continuation мають Gold-funded progress; finite-Books farming/restart adversarial tests |
| A13 | Природні contexts усіх шести задокументовані; global first-clear/protection gain та фінальні KPI залишаються tuning deviations |
| A14 | 9120 rows + contextual 120 rows + funded same-checkpoint continuations, sensitivity і actual boundary duty |
| A15 | Domain/quote/UI states перевірено widgets на 400×620; manual desktop interaction неперевірена |
| A16 | Source/config/results/commands, hard rule proofs, negative balance findings і desktop limits розділено |

## Відтворення

З кореня репозиторію, після `flutter pub get`:

```sh
mkdir -p build/phase_03
set -o pipefail
flutter analyze --no-pub
flutter test --no-pub
dart compile exe tool/balance/phase_03_audit.dart -o build/phase_03/audit
build/phase_03/audit --seeds 20 --exclude contextual_adaptive | gzip -n > build/phase_03/baseline.json.gz
build/phase_03/audit --seeds 20 --only contextual_adaptive | gzip -n > build/phase_03/contextual.json.gz
dart run tool/balance/phase_03_traces.dart > build/phase_03/traces.json
dart run tool/balance/phase_03_natural_crit.dart > build/phase_03/natural_crit.json
dart run tool/balance/phase_03_payback.dart > build/phase_03/payback.json
dart run tool/balance/phase_03_domain_diagnostics.dart > build/phase_03/diagnostics.json
python3 tool/balance/reproduce_phase_03_previous.py 20 > build/phase_03/previous.json
python3 tool/balance/reproduce_phase_03.py audit 20 > build/phase_03/frozen_current.json
```

Великі raw audit JSON збережено в gzip без втрати даних. Для читання: `gzip -dc docs/balance/phase_03_baseline.json.gz > build/phase_03/baseline.json`.

[Phase-2 baseline](balance/phase_02_baseline.json) й [точний попередній source](balance/phase_03_previous_source.tar.gz) з [SHA-256 metadata](balance/phase_03_previous_metadata.json) збережено перед змінами; archived helper smoke на одному seed відтворив executable report. Поточні source і artifact checksums — [metadata](balance/phase_03_source_metadata.json), [архів](balance/phase_03_source.tar.gz). Repeat smoke всіх 76 сценаріїв на seed 1 збігся з первинним JSON; фінальні 20-seed звіти повторно згенеровано після terminal-cursor guard і додавання `firstClearFrontier`.

Build/live desktop не запускались. Коміти цього етапу не створювались.
