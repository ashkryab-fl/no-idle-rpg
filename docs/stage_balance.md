# Етапи, XP та нелінійна складність

Етап пригоди й рівень персонажа мають різні ролі. Етап визначає ворогів; XP постійно підвищує HP і damage героя. HUD показує етап та кількість завершених перемог. Statistics окремо показує character level/XP.

На етапі потрібно 12 перемог (`ProgressionBalance.enemiesPerStage`). Після смерті герой повертається на початок попереднього етапу, мінімум Stage 1. Усі 12 боїв треба пройти заново. XP, character level, Gold, Books та придбані апгрейди зберігаються, тому цикл Stage 10 → смерть → Stage 9 → 12 перемог → Stage 10 дає ресурси для наступної спроби.

## Джерела та вибір формули

[Anthony Pecorella, The Math of Idle Games, Part I (Kongregate)](https://www.kongregate.com/id/pages/the-math-of-idle-games-part-i) описує експоненційне зростання, співвідношення income/cost та роль upgrades у подоланні наступної стіни прогресу. Це поширений підхід для incremental games, але він не встановлює універсальних коефіцієнтів enemy HP/damage.

[Pol Vilaseca та Pietro Guardascione, Breaking down the metagame design in a mobile RPG (King)](https://www.gamedeveloper.com/design/breaking-down-the-metagame-design-in-a-mobile-rpg) виводять геометричне зростання stats для combat, який залежить від співвідношення enemy HP та hero attack. Вони перевіряють баланс через кількість ударів і симуляцію боїв.

Застосовано геометричну формулу `stat(s) = base × growth^(s − 1)`. Збережені коефіцієнти проєкту є стартовим налаштуванням балансу, а не стандартом жанру:

```text
enemyHP(s)     = baseHP     × 1.08^(s − 1)
enemyDamage(s) = baseDamage × 1.065^(s − 1)
goldReward(s)  = baseGold   × 1.10^(s − 1)
bookDrop(s)    = baseBooks  × 1.10^(s − 1); probability = 0.28
xpReward(s)    = baseXP     × 1.07^(s − 1)
hero HP/damage level multiplier(L) = 1.015^(L − 1)
```

Attack speed, crit chance і crit damage визначаються типом ворога та не ростуть від етапу. Кожен етап множить HP на 1.08, damage на 1.065; абсолютний приріст збільшується з етапом, тому зростання нелінійне. Кількість перемог усередині етапу, час, distance і level героя не змінюють enemy stats.

| Stage | Enemy HP × | Enemy damage × | Gold/Books × | XP × |
|---|---:|---:|---:|---:|
| 1 | 1.000 | 1.000 | 1.000 | 1.000 |
| 10 | 1.999 | 1.763 | 2.358 | 1.838 |
| 25 | 6.341 | 4.533 | 9.850 | 5.072 |
| 50 | 43.427 | 21.884 | 106.719 | 27.530 |

## Оцінка балансу

Для первинного налаштування можна використовувати `killTime ≈ enemyHP / heroDPS`, `survivalTime ≈ heroHP / enemyDPS`, `receivedDamagePerKill ≈ enemyDPS × killTime` і `goldPerSecond ≈ goldReward / (killTime + travel/animation time)`. Це наближення: дискретні удари, критичні події, залишковий HP між боями, level-up healing та апгрейди впливають на реальний результат.

Regression tests перевіряють stage-only scaling, повернення Stage 10 → 9 → 10 із повторними rewards, збереження character progression, rollback у HUD і migration saves. Коефіцієнти потребують окремого тривалого playtest для остаточного темпу гри.

## Лут і прокачка

Усі coefficients і base values зібрані в `lib/core/balance/progression_balance.dart`. Gold/Books ростуть на 10% за етап, XP — на 7%. Раніше book drop залишався рівно 1 незалежно від етапу; тепер росте кількість, шанс залишається 28%. Очікувана кількість книг за kill: `chance × baseBooks × 1.10^(stage − 1)`. На Stage 1/10/25 за 12 перемог очікується приблизно 3.36/7.92/33.10 Books. Це середнє, а не гарантований drop. `Amount` зберігає дробові rewards без округлення при кожному kill.

Формула ціни залишається геометричною: `cost(u) = baseCost × r^u`, де `r = 1.1405` для Gold і `r = 1.1605` для Books. Ціна наступного upgrade росте швидше, ніж його +5% HP/damage, тому повторний farming лишається частиною циклу. x10 використовує точну суму геометричної прогресії; MAX аналітично шукає доступну кількість із numeric rounding correction.

| Stat | Effect при сумарних u рівнях Books + equipment |
|---|---|
| HP / damage | `base × 1.05^u × 1.015^(characterLevel − 1)` |
| Crit chance | `min(0.8, 0.05 + 0.001 × u)` |
| Crit damage | `1.5 + 0.01 × u` |

Швидкість атаки героя стала: 1 атака/с, апгрейди швидкості й Boots прибрані з каталогів та UI. Старі рівні speed/boots у збереженнях ігноруються при розрахунку stats. Шанс crit росте на 0.1 відсоткового пункту за кожен рівень Books або Helmet до cap 80%. Crit damage росте на 0.01× за рівень Books або Amulet без cap; він впливає на очікуваний DPS пропорційно шансy crit. Формула DPS: `damage × attackSpeed × (1 + critChance × (critDamage − 1))`.

Базові ціни: Books damage/HP — 1, crit/critDamage — 2; Gold weapon/armor — 20, helmet — 35, amulet — 30. Коефіцієнти є налаштуванням цього проєкту, а не універсальними числами жанру. Нові tests перевіряють реальний цикл farming → MAX purchase → зростання stats, комбінований критичний DPS, незалежні loot/XP multipliers та величини понад double range.

## Поступове сповільнення протягом місяця

Ціль — невелике відставання сили героя від HP ворогів на довгій дистанції. Дві незалежні лінії прокачки (Gold і Books) та XP враховані разом. Ціни підняті лише на 0.05 процентного пункта: 14% → 14.05% для Gold, 16% → 16.05% для Books. HP/damage upgrade залишається +5%; рівень героя дає +1.5%. Складність змінюється тільки після проходження етапу, не від календарного часу.

Для наближеної перевірки довгостроковий приріст damage за етап оцінюється так:

```text
upgrade log growth = ln(1.05) × (ln(1.10)/ln(1.1405) + ln(1.10)/ln(1.1605))
XP log growth      = ln(1.015) × ln(1.07)/ln(1.12)
enemy HP log growth = ln(1.08)
```

Сумарний приріст героя трохи нижчий за приріст enemy HP. Це оцінка ресурсного бюджету, яка не враховує дискретність покупок, накопичення валют, capped crit chance та additive crit damage. Остаточний темп перевіряється моделлю боїв.

`tool/simulate_progression.dart` використовує поточні EnemyFactory/Spawner, damage/crit, attack animation hit timings, loot, XP, ціни та CharacterStats. Він моделює travel, approach, death/reward/respawn durations, збереження HP між боями й відкат після смерті. Покупки відбуваються після бою приблизно раз на активну годину: кожна валюта розподіляється 37.5% damage / 37.5% HP / 15% crit / 10% crit damage. Залишки накопичуються. Idle rest/offline час не враховується.

Результати на трьох seeds, старт із нового персонажа. Для кожного seed взято медіану часу перших проходжень останніх 20 етапів (із повторним farming після смертей), потім медіану між seeds:

| День | 8 активних годин/день | 24 активні години/день |
|---|---:|---:|
| 1 | 1.97 хв | 1.76 хв |
| 7 | 1.89 хв | 4.53 хв |
| 14 | 2.88 хв | 13.74 хв |
| 30 | 8.14 хв | 39.37 хв |

За основного сценарію 8 годин на день час етапу через місяць збільшується приблизно у 4.1 раза. На початку значну частину часу займають travel і animations; коли вороги потребують більше ударів, зростання стає помітнішим. Окремий наступний етап може бути швидшим через crit, склад ворогів або щойно куплений upgrade; ціль стосується середнього темпу на довгій дистанції. Цілодобова гра за місяць проходить значно більше етапів, тому slowdown сильніший.

Це event simulation без frame/render ticks та ручний playtest вона не замінює. Результати — [progression_pacing_30_days.json](progression_pacing_30_days.json). Відтворення з кореня проєкту:

```sh
dart run tool/simulate_progression.dart --hours-per-day 8 --seeds 3
dart run tool/simulate_progression.dart --hours-per-day 24 --seeds 3
```

Regression tests перевіряють невеликий додатний розрив між приростом enemy HP та бюджетом damage, і місячний тренд за 8 годин на день. Повний `flutter test --no-pub`: 95 tests passed.
