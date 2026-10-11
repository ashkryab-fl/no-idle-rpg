# Таланти спеціалізації та джерела Books

Дата: 11.10.2026. Детальний розбір третього етапу [загального плану](balance_refactoring_plan_v2.md). Передумови: [видалення рівнів героя та XP](phase_01_remove_hero_levels.md) і [розділення валют та криві спорядження](phase_02_currencies_and_equipment_curves.md).

Мета — дати Books власну роль: оплачувати вибір між ефективністю проти босів, витривалістю та економікою мандрівки. Gold продовжує купувати чотири предмети базового спорядження. У цьому етапі реалізуються всі шість погоджених талантів, їхні ранги й відкриття, три пари альтернатив, фіксація вибору на спробу етапу та нові джерела Books.

Очікуваний результат — гравець змінює спеціалізацію відповідно до поточної перешкоди, а симулятор показує ціну цього вибору. Кращий дохід Gold допомагає через реальні покупки, але втрата бойової альтернативи має значення. Books більше не є другим способом купити ті самі HP/damage/crit.

Це документ майбутньої реалізації. Поточний код ще має XP, Books-stat upgrades і випадкові Books зі звичайних ворогів; етапи 1–2 описані, але не реалізовані в межах цієї роботи. Числа в цьому документі — стартовий профіль для перевірки, а не підтверджений баланс. Умови взаємовиключення й контексти шести ефектів походять із прийнятого плану; конкретні ціни, пороги, ліміти повторних нагород і коефіцієнти нижче є запропонованими рішеннями.

## 1. Цілі та очікування

- Books створюють окреме рішення про спеціалізацію; їхня купівельна роль зрозуміла без пояснення внутрішньої архітектури.
- Кожен із шести талантів має корисний природний контекст, а не лише проходить штучний тест своєї формули.
- У кожній парі діє максимум один талант; вибір має альтернативну вартість протягом усієї спроби етапу.
- Приріст наступного рангу спадає; кінцеві межі не дозволяють нескінченну шкоду, повне лікування, імунітет до критів чи миттєву мандрівку.
- Основний дохід Books походить від нового прогресу. Звичайні вороги більше не генерують його за старою експонентою.
- Навмисна смерть, перезапуск, повторний reward callback і перемикання не відновлюють одноразові нагороди та не створюють нескінченний потік Books.
- Повний цикл Gold → спорядження → швидші перемоги → нові нагороди враховується для всіх спеціалізацій, включно із захисними.
- Ігровий темп, rest, attack speed і софт-кап crit від 25% зберігають правила попередніх етапів.

Не очікуємо рівного розподілу Books між талантами або однакового часу проходження всіх восьми комбінацій. Очікуємо ситуацій, у яких змінюється найкращий вибір, і відсутності обов'язкової для всіх фаз економічної чи бойової гілки. Прогрес без талантів може бути повільнішим, але перші Books не повинні вимагати вже придбаного таланта.

## 2. Що саме отримує гравець

Три групи по дві картки. Ранг показує придбану силу; активність показує вибір для наступної спроби; окремий стан пояснює, що діє зараз. Придбати альтернативний талант можна, навіть коли активна інша картка тієї самої групи.

| Група | ID / робоча назва | Ефект | Альтернатива, від якої відмовляємось |
| --- | --- | --- | --- |
| Полювання на босів | `boss_damage` / Шкода босам | Додаткова шкода тільки босам | Бонус Gold першого проходження |
| Полювання на босів | `first_clear_gold` / Нагорода першого проходження | Бонус до окремої Gold-нагороди за перший clear stage | Швидше вбивство боса |
| Витривалість | `stage_heal` / Відновлення після етапу | Частина max HP після повного завершення stage | Захист від бонусної шкоди crit |
| Витривалість | `crit_protection` / Захист від критів | Зменшення додаткової enemy crit шкоди | Відновлення між етапами |
| Мандрівка | `shorter_travel` / Коротший шлях | Скорочення pre-encounter travel | Додатковий Gold за завершення stage |
| Мандрівка | `stage_gold` / Gold за етап | Gold за допустимий повний clear stage | Частіші encounter через коротший шлях |

Відкриття й перша покупка — різні дії. Відкритий талант рангу 0 не має ефекту; Books списуються тільки за купівлю рангу. Безкоштовне відкриття групи не дарує всі її ефекти. Відсутність вибору допускається, зокрема до першої покупки.

Після першого clear Stage 1 гравець одержує Books і бачить дві boss-альтернативи. Купівля рангу 1 дає перший відчутний вибір для наступної спроби. Після наступних milestones з'являються витривалість і мандрівка. Ніякого рівня героя чи XP-гейта для цього немає.

## 3. Межі етапу і залежності

| Робимо тут | Завершуємо наступними етапами |
| --- | --- |
| Каталог шести талантів, ціни, ранги, gates, три пари | Загальний PurchaseQuote/UI polish для всіх типів покупок — етап 4 |
| Придбання за Books, окреме обрання та snapshot спроби | Повний persistence/recovery UX — етап 4 |
| Усі шість контекстних ефектів, typed нагороди і claim ledger | Фінальне калібрування всіх стратегій — етап 5 |
| First-clear/milestone Books; обмежений повторний boss Books | Фінальні boss HP/damage/crit/reward профілі — етап 6 |
| Мінімальне збереження нових станів без повторних виплат | Desktop темп, читабельність вибору та реальний input/rest — етап 7 |
| Runner, контрольні traces й початкові восьмикомбінаційні прогони | Доведення цільових коридорів дня 30 — етап 5 з етапом 6 |

Без мінімального persistence цей етап не можна приймати: перезапуск не має скидати first-clear, повертати вибір посеред спроби або повторно платити Books. Це необхідна залежність механіки, навіть якщо загальний save-рефакторинг стоїть наступним пунктом.

Для діагностики спочатку залишити enemy/equipment профіль прийнятого етапу 2. Якщо захисна чи boss-гілка не має природної користі, окремо запропонувати мінімальну зміну enemy/boss профілю. Вона фіксується новим profile ID і власним порівнянням; не приховувати її всередині «додавання талантів».

## 4. Відкриття, ранги й Books-ціни

Стартовий кандидат відкриття груп:

| Умова прогресу | Що відкривається |
| --- | --- |
| Перше завершення Stage 1 | Обидва boss-таланти, ранги 1–3 |
| Перше завершення Stage 3 | Обидва endurance-таланти, ранги 1–3 |
| Перше завершення Stage 5 | Обидва travel-таланти, ранги 1–3 |
| Перше завершення Stage 20 | Ранги 4–6 для вже відкритих талантів |
| Перше завершення Stage 100 | Ранги 7–10 для вже відкритих талантів |

Gates використовують історичне перше проходження, а не поточний stage після rollback. Відкриття не втрачається після смерті. Пороги 1/3/5/20/100 перевіряти за часом фактичного досягнення: номер stage сам по собі не задає прийнятний темп.

Кандидат — 10 рангів у кожного таланта, власні налаштовувані ціни. Для початкового порівняння однаковий `C(n)=3×1.6^n Books`, де n — поточний ранг 0–9. Ранг 1 коштує 3, наступний — 4,8; вся гілка — приблизно 544,755814 Books, усі шість — 3268,534883. Це оцінка вартості, не часу прокачування.

Books залишаються `Amount`: дробові ціни допускаються чинною числовою моделлю. UI показує їх достатньо точно; відображуване округлення не визначає affordability. Якщо продуктово потрібні цілі Books, це окремий варіант профілю з визначеним округленням кожної ціни й узгодженими single/bulk сумами.

Межі покупки: доступний Books wallet, milestone gate, rank cap та позитивна зміна власного ефекту. Не блокувати rank `stage_heal`, `first_clear_gold` або неактивної альтернативи через нуль поточного звичайного DPS. Така покупка змінює придбану можливість, а не обов'язково поточний CombatStats.

Купівля не активує талант приховано, не повертає Books за вже придбані ранги й не лікує. Зміна обраного таланта безкоштовна; повернення/перерозподіл Books у цій версії не вводиться. Альтернативу можна прокачати окремо. Наслідок для довгого горизонту: гравець може придбати обидві гілки, але не використовує їх одночасно.

Перевірити темп рангу 1, відкриття наступної групи й останніх рангів у день 1/7/30. Якщо дерево купується повністю в першу сесію або нові Books не дають корисного рішення до дня 30, змінити rewards/ціни/gates/rank cap; не повертати старий глобальний stat-магазин як утилізатор надлишку.

## 5. Криві diminishing returns

Для першого профілю всі ефекти використовують одну форму з окремими параметрами:

```text
F(n; R, τ) = (1 − exp(−n/τ)) / (1 − exp(−R/τ))
effect_i(n) = B_i × F(n; R_i, τ_i),  0 ≤ n ≤ R_i
```

Кандидат R=10, τ=3. Ранг 0 → нуль; ранг 10 → рівно B. Це обмежене дерево зі спадним приростом, не необмежена асимптота. Не обчислювати ранги понад R і не продавати їх. Величини R/τ/B незалежні для шести талантів; спільна форма не означає однакову користь.

| Ранг n | F(n) | Добавка наступного рангу до F |
| ---: | ---: | ---: |
| 0 | 0 | 0,293955247 |
| 1 | 0,293955247 | 0,210628138 |
| 2 | 0,504583385 | 0,150921656 |
| 5 | 0,841130895 | 0,055520974 |
| 9 | 0,985364830 | 0,014635170 |
| 10 | 1 | Покупка заборонена |

| Ефект | B стартового кандидата | Ранг 1 | Межа при ранзі 10 |
| --- | ---: | ---: | ---: |
| Boss damage bonus | 0,50 | +14,6978% | +50% |
| First-clear Gold bonus | 0,50 | +14,6978% від first-clear бази | +50% від цієї бази |
| Stage heal fraction | 0,20 | 5,8791% max HP | 20% max HP |
| Enemy crit bonus reduction | 0,60 | 17,6373% додаткової crit шкоди | 60% додаткової crit шкоди |
| Travel time reduction | 0,25 | 7,3489% pre-encounter travel | 25% цієї частини часу |
| Stage Gold fraction | 0,50 | 14,6978% nominal stage kill Gold | 50% цієї бази |

Вибір малих/середніх/великих B: економіка {0,25;0,50;0,75}, heal {0,10;0,20;0,30}, crit protection {0,40;0,60;0,80}, travel {0,15;0,25;0,35}, boss damage {0,25;0,50;0,75}. Спочатку ізолювати по одному ефекту; далі спільні відібрані профілі. Не запускати весь декартів добуток без потреби.

Точні B не приймати лише через красиву таблицю. Відсоток від рідкісної нагороди, частка max HP і частка crit bonus мають різні одиниці й частоту застосування. Ранній приріст та ціну перевіряти за фактичним результатом, а не за рівністю чисел між картками.

## 6. Контракт кожного ефекту

### Шкода босам

Hero hit проти `enemy.isBoss`: `baseDamage × critFactor × (1+bossBonus)`. Проти звичайного ворога множник дорівнює 1. Це контекстний множник після equipment calculation; він не змінює базовий damage, crit chance/multiplier або APS.

При damage=100, crit multiplier=2 і bonus=0,5: normal enemy отримує 100/200, boss — 150/300. Критичність і кількість RNG draws не змінюються. Зменшення TTK визначати дискретними ударами: +50% шкоди не гарантує −33,3% часу через overkill, markers та смерть героя.

### Бонус Gold першого проходження

На першому повному clear конкретного stage створюється окрема база `firstClearGoldBase(stage)` для всіх build. Активний талант додає `base × firstClearBonus`. Він не множить kill Gold, stage Gold, Books або milestone Books.

Кандидат бази — nominal boss kill Gold цього stage без talent bonuses. Якщо boss reward multiplier ще не змінено, використовувати чинний профиль; варіант ×2 boss Gold позначити окремо. При base=24 і bonus=0,5 виплата first-clear становить 24+12; звичайна boss kill reward нараховується окремо один раз.

First-clear без активного таланта також помічається отриманим. Пізня купівля чи вибір таланта не доплачує за минулі stages. Після rollback той самий stage не стає first-clear знову. Гравець обирає між швидшим подоланням боса зараз і додатковою нагородою за успішний clear.

### Відновлення після етапу

Після успішного завершення всіх п'яти хвиль, в settlement цього stage, живий герой відновлює `maxHp_at_settlement × healFraction`, але не більше missing HP. Max HP береться з актуального спорядження, fraction — зі snapshot поточної спроби. Один clear → один heal event, включно з допустимим повторним clear.

При max HP=120, поточному HP=60, fraction=0,2: результат 84. При HP=110: результат 120, фактичне відновлення 10. Після звичайної хвилі, покупки рангу, вибору чи перезапуску heal не виникає. Герой із нульовим HP не оживає від stage heal; штатний respawn окремий.

Талант не є пасивним regen або повним XP-healing. Він допомагає серіям успішних stages, але не рятує від летального удару до clear. Повторне завершення для лікування може бути локально корисним; треба виміряти повну вартість боїв/смерті, а не забороняти сам факт такого вибору.

### Захист від критів

Enemy noncrit damage=D. Для критичного удару з multiplier=M≥1 і reduction=q:

```text
incomingCrit = D × [1 + (M−1) × (1−q)]
```

При D=100, M=1,5, q=0,6: noncrit лишається 100, crit стає 120 замість 150. Скорочується тільки bonus 50→20; не вся шкода 150→60. Chance enemy crit не змінюється, повного імунітету немає. Навіть q=1 лишив би D, але кандидат обмежений q≤0,8.

За актуальних p=3%, M=1,5 зниження середньої шкоди при q=0,6 лише приблизно 0,8867%. Це ризик слабкої гілки. Користь може бути у запобіганні рідкісній летальній серії, але її треба показати на природних HP/crit traces. Один crafted crit-hit не доводить життєздатність таланта.

Порівняти deaths, lethal crit share та стіни з healing-альтернативою. Якщо користі немає, перевірити окремі boss crit профілі, наприклад chance 8/12/15% і multiplier 1,5/1,75/2. Не приймати штучно смертоносних ворогів лише для виправдання таланта; їхня прохідність без цієї спеціалізації також перевіряється. Фінальні boss числа належать етапу 6, мінімальний придатний контекст потрібен уже тут.

### Коротший шлях

Скорочується тільки `traveling` до spawn. `enemyApproach`, APS/attack playback, enemyDeath, reward hold, heroDeath/respawn, rest і suspend не прискорюються. Для sampled base encounter distance L: target `L×(1−travelReduction)`, при тій самій швидкості руху. Так час зменшується разом із фактично пройденою дистанцією; світ не телепортується, renderer використовує той самий movement.

L обирається з поточного 90–160; reduction≤0,35 лишає додатну дистанцію. Snapshot фіксується до першого travel stage, тому користь не можна отримати до фіксації вибору. Upgrade посеред travel не перераховує залишок поточного encounter.

Якщо travel займає 4 с із циклу 10 с, reduction=25% дає цикл 9 с й приблизно +11,11% encounter/с, а не +25% reward або +33,33% усього доходу. Rest блокує adventure незалежно від talent: encounterRemaining не зменшується, rewards не нараховуються.

### Gold за етап

На допустимий повний clear виплачується додатково `nominalStageKillGold(stage) × stageGoldFraction`. База — сума nominal Gold п'яти wave rewards за збереженим encounter/reward планом спроби, без first-clear, milestone і talent bonuses. Для майбутніх різних enemy definitions план семплюється один раз на спробу; не обчислювати «середнього ворога» замість фактичної бази. Смерть до clear не виплачує частковий stage bonus.

При чотирьох nominal rewards 12 і boss 24: база 72; fraction=0,5 → +36 Gold. Це окрема ledger line; kill rewards 72 не виплачуються вдруге під виглядом stage reward.

Кандидат захисту повторних проходжень: бонус доступний на першому clear та двох наступних clear цього самого stage. Далі звичайний kill Gold зберігається, stage talent bonus дорівнює нулю. Ліміт рахується за всіма успішними clears, навіть коли талант був неактивний; він не накопичує відкладені виплати. Ця політика нова й потребує перевірки: вона структурно обмежує bonus death-farm, але може послабити талант у довгому фармі.

UI явно показує «бонус на перше та 2 повторні проходження» і залишок допустимих повторів. Для farm-heavy фази порівняти альтернативу без цього ліміту з нижчим B; дозволити її у фінальний профіль лише за доказу, що нескінченний deliberate-death цикл не обганяє життєздатний прогрес через бонус. Не залишати невизначене «перевіримо repeat» без конкретної policy у runner.

## 7. Books: джерела, суми й обмеження

Кандидат reward policy:

| Подія | Books | Повторюваність |
| --- | ---: | --- |
| Звичайний enemy kill | 0 | Старий random drop і його growth прибрані |
| First clear конкретного stage/boss | 3 гарантовано | Один раз на stage |
| Другий і третій clear того самого stage | По 1 гарантовано | Дві повторні виплати на stage за весь прогрес гри |
| Milestones 5, 10, 20, далі кожні 20: 40/60/80… | По 5 гарантовано | Один раз на milestone ID |
| Смерть, часткове проходження, вибір/покупка, rest/suspend | 0 | Жодного claim |

Milestone 20 має один ID і одну виплату, навіть якщо відповідає початку періодичного ряду. Не складати два збіги правила в +10. Books не залежать від Gold-талантів, enemy `bookRewardGrowth`, hero level або APS. Перші 3 Books гарантовані після природного Stage 1 без талантів.

Формально для stage s, перед clear, `ordinal = completedClears(s)+1`:

```text
if ordinal == 1: stageBooks = 3
elif ordinal in {2,3}: stageBooks = 1
else: stageBooks = 0
milestoneBooks = 5 if matchingMilestoneNotClaimed else 0
```

Усередині одного stage максимум 5 Books плюс, за наявності, його одноразовий milestone. Без нових first-clears доступний повторний Books-резерв скінченний: максимум 2 на кожен уже завершений stage. Це не per-session/per-day ліміт, його не скидає restart або час.

Books за first-clear — і є основна boss нагорода прогресу; не додавати ще окремі «3 boss Books» до тих самих 3. Ліміт повторів stage Gold і Books перевіряє один completion ordinal, але валютні проводки незалежні: Books гарантовані, Gold bonus потребує активного таланта.

Ризик: на справжній стіні гравець може вичерпати Books доступних повторів. Тоді звичайний Gold farming і equipment повинні залишати шлях подолання. Не вирішувати блокер поверненням random Books з усіх mobs або нескінченним restart. Якщо ранги конкретної спеціалізації фактично обов'язкові, доступний гарантований Books-бюджет до стіни має покривати їх без безповоротного вибору-пастки.

Порівняти first-clear/Books-budget профілі з repeat limit 0/1/2 і first-clear сумами 2/3/5. Частка first-clear+milestone у Books за цільові productive horizons має бути основною; початковий орієнтир ≥60% загального заробітку в адаптивному progress build. Це гіпотеза для калібрування, не тестова константа для кожного seed або no-progress farm policy.

## 8. Спроба етапу та фіксація спеціалізації

Розділити три стани: `ownedRanks`, `selectedForNextAttempt`, `activeAttempt`. Snapshot містить stage, attempt ID, по одному talent ID або null у кожній парі, ранги/ефекти, effect profile version і стабільний encounter/reward план. Equipment купується й діє за правилами етапу 2; його ранги не заморожуються разом із талантами.

1. На старті stage, до першого travel, валідовані selected IDs/ranks копіюються в immutable snapshot. Немає активності двох альтернатив однієї пари.
2. У межах цієї спроби travel, hero/foe hits, stage heal і нагороди використовують один snapshot.
3. Нові покупки й зміна selection можуть прийматись у будь-якій фазі, але лише як конфігурація наступної спроби. Чинний ефект не змінюється.
4. На clear старий snapshot застосовується до всього settlement, включно з boss bonus, Gold і heal. Спочатку завершується спроба; наступний snapshot створюється перед першим продуктивним travel нового stage, після reward hold. Покупка/selection у цьому проміжку вже може діяти в наступному stage.
5. На смерті спроба закінчується без stage settlement. Stage rollback і повний respawn за чинними правилами; після respawn, перед першим продуктивним travel, нова спроба нижчого stage отримує queued selection. Kills Gold, уже отриманий до смерті, не забирається.
6. Rest, suspend, закриття панелі й restart не закінчують спробу та не застосовують queued selection. StageKills і snapshot відновлюються разом.

Купівля рангу на Wave 4 не підсилює boss Wave 5 цієї спроби. Вибір stage Gold перед останнім боєм після чотирьох travel із shorter_travel також не підміняє snapshot. Якщо покупки/selection і settlement потрапляють в один tick, порядок визначається: поточний settlement завжди зі старим snapshot; selection, прийнята до старту наступного snapshot, діє в наступному. Якщо rest блокує перший travel після clear, новий snapshot ще не фіксується; якщо rest настав посеред уже початого stage, snapshot залишається. Автоматичний старт stage не гарантує, що гравець встигне купити ранг за час reward hold: UI завжди показує, з якої наступної спроби діятиме покупка.

Формально є 8 повністю обраних комбінацій. До відкриття/купівлі груп можливі null-стани; не змушувати гравця обирати непридбаний ранг. Death як спосіб швидше змінити вибір має ціну в часі й rollback; перевірити цю policy, не припускати, що гравець її не використає.

## 9. Settlement, claim ledger та restart

Чинний runtime видає reward після enemy death animation, тоді збільшує stageKills; runner сьогодні видає його раніше. У новій моделі stage settlement прив'язаний до тієї самої settled death boundary. Не платити first-clear на fatal hit, spawn боса або вході у reward animation.

На останній wave одне логічне завершення має:

1. Визначити enemy kill reward, stage s, completion ordinal, first-clear eligibility та milestone ID зі стану до завершення.
2. Обчислити всі Gold/Books lines і фактичний heal зі старого snapshot та актуального max HP.
3. Єдиним оновленням застосувати wallets, HP, kill/completion counters, first-clear/milestone claims, unlocks та завершення спроби; stage переходить у s+1.
4. Передати immutable reward breakdown для UI і capture узгодженого save. Повтор тієї самої події не може ще раз змінити стан.

ID події/ознака committed результату потрібні на domain boundary; не покладатися на те, що анімація ніколи не надішле повторного callback. Дані до або після settlement зберігаються цілісно: неприпустимий save з виплаченим wallet і невстановленим first-clear claim. Pending result, якщо серіалізується, має явний статус; при resume він або завершується один раз, або вже committed і не повторюється.

Для послідовного прогресу first-clear ledger може бути `highestFirstClearedStage`; це окреме поле від поточного stage. Для майбутніх непослідовних зон знадобляться IDs. Repeat ledger зберігає для вже cleared stage використані 0/1/2 повтори; після двох можна зберігати saturated стан. Оцінити розмір/serialization time на великих stage; не перезаписувати всю історію кожного encounter без потреби. Milestone claim визначається окремим ID або однозначно виводиться з монотонного frontier, якщо виплата завжди входить у той самий settlement.

Мінімальний save цього етапу: talents ranks/unlocks, selection, activeAttempt, Stage/Wave, first-clear frontier, repeat eligibility, milestone claims, wallets і необхідний HP/death state. Профіль активної спроби відновлюється без перерахунку на нові B. Невідома версія профілю — явна несумісність/recovery, а не мовчазний новий ефект.

Зараз `GameSimulation` при конструюванні ставить повний HP; чинний save HP не містить. Це вже існуючий restart heal, який може маскувати різницю heal/protection. Для приймання нової спеціалізації його потрібно закрити мінімальним persistence-контрактом: restart не дає безкоштовного HP або нового snapshot. Незавершений encounter може відновлюватись на тому самому wave із заново створеним ворогом того самого encounter plan і збереженим поточним HP, без reward/heal; нульовий HP відновлює death/respawn, не живого героя. Точне frame/RNG-resume й UX пошкоджених станів деталізуються етапом 4. Pending settled death не можна трактувати як простий незавершений бій і втратити чи дублювати settlement. Між завершенням старої спроби й першим travel нової save явно позначає boundary без активного snapshot; load не повертає вже завершену спробу.

Періодичний backup може відкотити весь узгоджений checkpoint, включно з wallet і claim. Не заявляти захист від навмисного ручного редагування save або його старої копії. Вимога — штатний restart/recovery не зберігає вже виплачені гроші разом із повернутою eligibility. Reset усієї нової гри очищує обидва ledger й таланти; смерть цього не робить. Відомі старі дорелізні сейви відкидаються, current/future/corrupt розрізняються за попереднім планом.

## 10. UI та контракти покупок

Картка: назва, контекст ефекту, придбаний ранг і його межа, ефект зараз/наступного рангу, Books-ціна, gate, status активної та наступної спроби. Кнопки «Придбати ранг» і «Обрати» не змішують оплату з перемиканням. При купівлі показати, що поточний stage використовує попередній ранг, якщо snapshot уже зафіксований.

Приклади потрібних пояснень: «Лише проти босів»; «Відновлення після всіх 5 хвиль»; «Зменшує бонусну шкоду криту»; «Не впливає на бій і відпочинок»; «Перше проходження цього етапу»; «Бонус за етап: лишилось 2 повторні проходження». Не називати protection «−60% усієї шкоди» чи travel «+25% Gold».

Reward breakdown окремо показує kill Gold, first-clear base/bonus, stage bonus, first-clear/repeat/milestone Books. Не зводити все до одного числа, через яке неможливо зрозуміти джерело Books. Коли eligibility закінчилась, причина видима до покупки/вибору; не показувати ще доступну нагороду, якої не буде.

Domain command приймає тільки валідний catalog ID і count. Books-wallet визначається типом покупки. Перевіряються rank/gate/cost перед виконанням; невдалий запит нічого не змінює. Single/bulk купують те саме число рангів за ту саму ціну; MAX обмежений і R, і gate. Вибір дозволений тільки для відкритого рангу ≥1 й валідної пари. Невідомий ID, negative count, gate mismatch або corrupted pair відхиляються поза UI.

Preview розрізняє приріст owned effect та activeAttempt effect. Талант може мати нуль ефекту в поточному normal hit, але позитивний у власному контексті. Загальний quote для всього магазину входить в етап 4; мінімальні валідовані talent quote/commands потрібні зараз.

## 11. Архітектура та місця інтеграції

Запропоновані нові модулі — назви для реалізації, їх ще немає:

| Шар / місце | Відповідальність |
| --- | --- |
| `lib/core/balance/progression_balance.dart` | Talent/reward профілі, B/τ/R, Books costs, gates, repeat limits; version ID |
| `lib/domain/talents/` | Catalog, pair IDs, ranks, selection, snapshots, effect resolver; без animation залежностей |
| `lib/domain/economy/` | Typed reward lines, source ID, stage eligibility, settlement result; Gold і Books незалежні |
| `lib/game/systems/progression_system.dart` або заміна після етапу 1 | Talent purchase/select validation та equipment API з етапу 2 |
| `lib/game/systems/combat_system.dart` | Boss outgoing bonus, enemy crit bonus reduction; один roll критичності |
| `lib/game/systems/enemy_spawner.dart` | Стабільний attempt encounter план, nominal reward base; видалені random normal Books поля |
| `lib/game/systems/drop_system.dart` | Kill reward без XP/random normal Books; stage rewards через settlement, без generic multiplier для Books |
| `lib/game/systems/game_simulation.dart` | Життєвий цикл attempt, travel target, settled stage, heal/death/restart boundaries |
| `lib/app/game_controller.dart` | Команди, persistence capture й restart state; не власні формули талантів |
| `lib/presentation/` | Три групи, вибір зараз/потім, rank preview, reward breakdown; старий Books-stat магазин не повертається |
| `lib/core/persistence/` | Atomic snapshots/ledger, мінімальний round-trip й несумісна schema boundary |
| `tool/balance/`, targeted tests | Той самий resolver/settlement; незалежні RNG streams; policies, seeds і результати |

`CharacterStats.calculate` лишається джерелом базових equipment CombatStats. Контекстні ефекти застосовуються один раз за snapshot. Не записувати boss damage у глобальний damage, heal у max HP чи protection у crit chance. Не додавати всі шість ефектів через універсальний stat multiplier.

## 12. Gold-економіка, альтернативна вартість і синергії

Рахувати фактично зароблені проводки за джерелами і фактичний час: travel, approach, normal/boss combat, death/reward hold, failure/respawn та rest. Економічний талант підвищує лише свою reward-базу. Travel підвищує частоту encounter; boss damage зменшує час/отриману шкоду; витривалість зменшує невдалі спроби. Усі ці ефекти можуть підняти Gold/год і доступність спорядження.

```text
Gold_earned = Σ killGold + Σ firstClearBase + Σ firstClearBonus + Σ stageTalentBonus
Books_earned = Σ firstClearBooks + Σ repeatBooks + Σ milestoneBooks
Gold_per_productive_hour = Gold_earned / productiveHours
Gold_per_open_hour = Gold_earned / openHours
```

Реальний reinforcement після нового Weapon/Armor — очікуваний ефект, який потрібно симулювати. Помилка — двічі застосувати той самий reward-бонус або штучно підвищити kills/с без скорочення фактичного часу. Для source-compatible future bonuses відсотки збираються в одній обмеженій кривій; різні джерела не перемножуються довільно.

При nominal stage kills 72, first-clear base 24 та B=0,5: first-clear talent додає 12, тобто 12,5% до базового першого циклу 96; stage talent додає 36, тобто 37,5% до того самого циклу. Обидва можуть діяти разом, бо належать різним парам: earned=72+24+12+36=144, не `96×1.5×1.5`. Це приклад потенційно сильного спільного економічного вибору, а не схвалення його балансу.

Books-покупку не оцінювати як `BooksCost / extraGoldPerSecond`: одиниці різні. З одного checkpoint запускати альтернативні продовження з однаковим Books-бюджетом: купити economic rank або допустиму бойову/захисну альтернативу. Обидва build використовують однакове правило Gold-реінвестування. Виміряти час до цільового milestone, first wall recovery, deaths, progress frontier та час обгону альтернативи. Більший залишок Gold без кращого результату не є окупністю прогресу.

Розділити два експерименти: однакові ownedRanks й різні selection ізолюють активний ефект; різні Books investment policies перевіряють реальну ціну спеціалізації. Восьмикомбінаційний тест із безкоштовними rank 10 не є доказом балансу фінансових рішень.

Синергії: boss damage×crit може рятувати clear; heal×Armor підвищує абсолютний heal і число наступних перемог; crit protection залежить від залишкового HP та enemy burst; travel сильний у коротких боях і слабшає на довгому boss; first-clear+stage Gold прискорюють equipment. Перевірити всі, а не зменшувати один B незалежно від інших.

## 13. Синтетичні сценарії правил

| ID | Сценарій | Очікування |
| --- | --- | --- |
| T01 | Fresh game; clear 1/3/5/20/100, rollback | Точні pair/rank gates; перший talent доступний без XP; unlock не зникає |
| T02 | Curve ranks 0/1/2/5/9/10, negative/11 | Контрольні значення, спад дельт 1–10, cap; illegal rank відхилено |
| T03 | Books=0, достатньо Gold; locked/unknown talent | Немає покупки, wallets/ranks незмінні; Gold не підміняє Books |
| T04 | Придбати неактивну альтернативу; x1/x10/MAX через gate | Позитивний owned effect, actual count/cost; не змінюється snapshot чи HP |
| T05 | Select rank 0/unknown ID/wrong pair; обрати дві альтернативи | Валідація поза UI; максимум одна на пару; null допустимий |
| T06 | Зафіксувати snapshot, upgrade/select на Wave 2/4 | Поточні travel/combat/reward/heal незмінні; next attempt бере queued selection/ranks |
| T07 | Travel→stage Gold перед boss; death перед новою selection | Немає змішаного ефекту двох альтернатив; новий snapshot тільки після clear/respawn |
| T08 | Boss/normal, hero crit/noncrit, damage=100, M=2, b=0,5 | Normal 100/200, boss 150/300; APS/crit RNG незмінні |
| T09 | Enemy crit/noncrit D=100, M=1,5, q=0/0,6 | Noncrit 100; crit 150/120; нуль шкоди/імунітет не виникає |
| T10 | Max HP=120, heal fraction=0,2, HP 60/110/0 | Clear heal 24/10/0; normal wave/upgrade/select не лікують |
| T11 | Same base travel distance, reduction 0/0,25; approach/rest | Travel target 100%/75%; approach і clocks незмінні; під rest нуль progress |
| T12 | Nominal kills 72, boss 24; both economic effects 0,5 | First clear: kill 72 + base 24 + bonus 12 + stage 36; Books незалежні |
| T13 | Early-stage repeated clear ordinals 1/2/3/4 | Books 3/1/1/0; first-clear base/bonus тільки на 1; stage bonus тільки на 1–3 |
| T14 | Repeat quota використано з неактивним stage Gold, потім активувати | Немає відкладеного бонусу; UI показує правильний залишок |
| T15 | Normal kills у різних tiers; drop RNG extrema | Books=0 всюди; немає `bookRewardGrowth` або random normal drop |
| T16 | Milestone 5/10/20/40; повторний callback і rollback | По 5 Books один раз на ID; milestone 20 не виплачується двічі |
| T17 | Stage completed; повторити settlement event | Wallet/HP/claims/unlocks не змінюються вдруге; UI event не створює reward |
| T18 | Смерть на Wave 5 до settled boss death | Немає stage/first-clear/Books/heal; попередні kill rewards збережені; чинний rollback |
| T19 | Великий Amount і rank cap; неправильний profile/R/τ/B | Log math finite, без double overflow; invalid config відхилено; MAX bounded |
| T20 | No talents або all-null; equipment придбано під час спроби | Правила етапу 2, без пасивної сили/XP; equipment діє, talent snapshot не змінюється |
| T21 | Selection у reward hold / під rest після clear / після початку першого travel | До нового snapshot вибір діє на наступний stage; після фіксації — тільки на наступну спробу; стара нагорода завжди зі старим snapshot |

Похибка контрольних effect values до 1e−10 для double; великі Amount порівнювати в логарифмах з обґрунтованою похибкою. Валідувати 0≤n≤R, τ>0, R≥1, finite B; travel/heal/protection мають profile bounds нижче 1. Числа з прикладів T08–T14 задаються тестовим profile без обходу domain rules.

## 14. Persistence, порядок подій і parity

| ID | Сценарій | Очікування |
| --- | --- | --- |
| P01 | Save/load owned ranks, selection, Wave 3 і snapshot іншого рангу | Повний round-trip; active effect збережений, queued не активований |
| P02 | Restart після first clear / другого / третього / четвертого clear | Frontier/quota/claims збережені, повторних одноразових виплат немає |
| P03 | Restart посеред travel/combat, низький HP, queued upgrade | Немає free heal чи нового snapshot; encounter policy явна; reward не виникає |
| P04 | Crash/capture на межі settlement, duplicate callback, backup | Узгоджені wallet+claim+HP; pending або committed, не обидва; replay один раз |
| P05 | Death/respawn/reward phase resume; full new-game reset | Смерть не лікує до respawn, не скидає claims; reset очищує нову гру повністю |
| P06 | Legacy primary/backup, current corrupt/future version, invalid pair/profile | Відома legacy відкидається; решта — валідоване recovery/error, не silent reset |
| S01 | Контрольний trace runtime/runner на boss clear і death rollback | Ті самі ефекти, HP, rewards, gates, snapshots та counters після settled boundary |
| S02 | Парний trace з/без талантів, split combat/travel streams | Зміна ефекту не міняє сторонній RNG; travel змінює час, не переролює criticality |
| S03 | No-crit Stage 1 без талантів, без покупок | Природний clear із baseline етапу 1 (приблизно 28,2 HP), 3 Books, boss pair unlock |
| S04 | Шість контекстів, природні hits до перемоги/смерті | Ефект може змінити реальний clear/TTK/survival; forced kills не доводять прохідність |
| S05 | Duty/rest 25/50/75/100%, suspend і різні tick partitions | Жодного idle reward/progress; clocks і eligible boundaries узгоджені |

Для parity недостатньо однакового seed, якщо число RNG calls різниться. Використати контрольні event streams/encounter plans, а для стратегій — окремі streams combat/travel/selection. Без normal Books random draw послідовність старого спільного RNG закономірно зміниться; не видавати це за ефект талантів.

Повний restart-resume тест не можна замінити JSON round-trip. Перевіряється наступний фактичний settlement після load; саме він знаходить повторні виплати й підміну snapshot. Під час підготовки плану локальні сейви не очищуються.

## 15. Поведінкові прогони та прийнятність економіки

Baseline: прийнятий профіль етапу 2 з booksSpent=0; той самий профіль з новими rewards без талантів; по одному таланту; всі шість з реальними gates/цінами. Ізольовані кроки відокремлюють зміну джерел, додатковий first-clear Gold і власне ефекти.

Щонайменше 20 seeds для початкової діагностики: 30 хв, 1/3/7 productive hours, дні 1/7/30 за 7 productive hours/day. Окремі duty профілі використовують open time і справжні rest boundaries; не називати 7 productive hours сімома годинами відкритої програми. Для rare crit-death висновків збільшити кількість encounters/seeds до достатньої точності, а не вважати 20 seeds універсальним доказом.

Policies: всі 8 selection combinations з matched ownedRanks; no talents; adaptive purchases/selection; Books спочатку в Gold; Books спочатку в travel; boss damage focus; heal/protection focus; omit-one в життєздатному mixed build; рівномірний Books budget як контроль. Додати ранню невдалу Books-інвестицію й подальшу адаптацію без refund: чи є шлях з Gold farming, чи це необоротна пастка.

Cadence покупки: за доступністю, кожні 5 хв, раз на годину. Cadence selection — тільки stage boundary; policy може queue раніше, але не обходити snapshot. Gold investment policy однакова в ізольованих парах; у повному пошуку окремо adaptive й Weapon/Armor/Helmet/Amulet focus. Не називати просту евристику математично оптимальним гравцем.

Обов'язкові adversarial policies: death після boss для повтору stage; death заради швидкого switch; накопичення selection під rest; restart перед last wave/reward; повторний запит purchase/settlement. Локальна вигода від recovery/farm допускається; нескінченна бонусна Books-ферма або повтор first-clear — помилка правил.

Звітувати:

- P5/P50/P95 frontier і поточного stage окремо; normal/boss TTK P50/P90; deaths/100 encounters у вікні, first-wall recovery.
- Час відкриття груп/рангів, перша покупка та зміна selection; Books earned/spent/remaining за джерелами, saturated branches/quota.
- Gold за kills/first-clear base/first-clear bonus/stage bonus; Gold/ productive й open hour; реальні покупки equipment завдяки додатковому доходу.
- Активні комбінації, вкладення в усі шість талантів, коли змінюється найкраща наступна покупка; наслідок omit-one та full focus.
- HP перед boss/після clear, actual heal/missing HP, prevented crit bonus та lethal crit частка; Armor/respawn heal окремо.
- Travel savings й encounter/с з урахуванням approach/combat/rest; failed stage spend time і доступний repeat bonus бюджет.
- Paired differences у progress/time-to-milestone/deaths, інтервали невизначеності; за noisy ranking — додаткові seeds, а не довільний висновок.
- Після вичерпання повторних Books — time-to-effective-Gold-purchase і реальний шлях першої нової перемоги.
- Serialization/ledger size, single/bulk purchase latency, відхилені invalid/zero-effect events.

Кожен талант має показати корисний природний контекст і можливість альтернативи виграти в іншому типовому контексті. Орієнтири master-плану: користь вище seed-шуму, близько 5% релевантного поліпшення, mixed progress у межах приблизно 10–15% найкращої перевіреної стратегії. Це кандидати KPI для етапу 5; на етапі 3 потрібні traces, sensitivity й перелік відхилень, а не вигаданий «баланс пройдено».

У межах етапу 3 не приймати очевидно мертву гілку чи ранній softlock під обіцянку виправити пізніше. Якщо користь crit protection видно тільки на штучному ворогові з 100% crit, або економічний build виграє всі природні контексти незалежно від альтернативи, потрібна зміна придатного профілю до інтеграції. Остаточне доведення дня 30 і всіх boss-профілів лишається наступним етапам.

## 16. Чого тести не повинні показати

- Books з normal kills, їхнє експоненційне зростання або новий Books→HP/damage/crit глобальний магазин.
- Обидві альтернативи активні; travel використано на початку, а stage Gold того самого snapshot — після перемикання перед босом.
- Купівля рангу, вибір чи restart лікують, міняють чинний snapshot або повторно відкривають first-clear.
- Boss damage діє на normal foe, crit protection ріже весь hit або змінює enemy crit chance.
- Stage heal діє після однієї wave, переливає max HP, оживляє мертвого героя чи маскує старий XP-heal.
- Travel прискорює APS, approach/animations, проходить під rest або дає offline/catch-up reward.
- First-clear bonus множить усі kills/Books, stage base повторно виплачує kill rewards, bonuses довільно перемножуються.
- Четвертий clear у кандидатному профілі знову дає Books/stage bonus; milestone 20 видає дві виплати.
- Wallet зберігся після виплати, а claim/quota — ні; duplicate settlement, restart/recovery або rollback видають нагороду вдруге.
- Talent покупка відхилена лише тому, що зараз normal DPS не змінюється, або Gold оплачує Books-запит.
- Дерево завершене майже одразу або доступний Books-бюджет лишає незворотну ранню пастку; повторний farm приховує відсутність шляху прогресу.
- Protection корисний тільки у handcrafted 100% crit test; economic focus чи інший один параметр завжди найкращий у всіх типових фазах.
- Симуляція дає непояснений результат через іншу reward boundary, старий XP або суміш productive/open time.
- Усереднені підсумки приховують непрохідні seeds, банкрутство Books чи зникнення реальних рішень на довгому горизонті.

Перші десять — rule/state інваріанти з точними сценаріями. Останні чотири потребують natural traces і статистики. Максимальна спеціалізація може локально вигравати; no-purchase стіна допустима; нуль deaths в окремому seed не є самостійною помилкою.

## 17. Ризики та відповідь

| Ризик | Як помічаємо | Що робимо |
| --- | --- | --- |
| Захист від критів надто слабкий | Natural lethal-crit traces, omit-one, heal comparison | Ціна/B/контекстний boss crit profile; не змінювати семантику на загальний armor |
| Дві економічні гілки розганяють equipment | Reinvestment й matched Books budget, paired horizons | Source bases/B/cost/gates; порівняти втрату boss/travel альтернатив |
| Repeat caps роблять stage Gold непотрібним у farm фазі | Quota saturation, alternative selection, natural income share | Перевірити нижчий repeatable B як окремий профіль, не прибирати caps без audit |
| Finite Books заводять неправильний ранній build у пастку | Wrong-first-investment policy, empty-wallet wall | Budget/ціни/gates і Gold-only viability; перша покупка не повинна бути обов'язковим секретом |
| Hero heal + Armor усувають весь релевантний ризик | Full-cycle HP balance, deaths window, prevention surplus | Heal B/cost й enemy profile разом; не додавати enemy damage автоматично |
| Switch exploit або upgrade діє посеред спроби | Wave-by-wave snapshot trace, rest/restart | Immutable activeAttempt, queued selection/ranks |
| Restart дає повний HP і нівелює витривалість | Load→next encounter/settlement тест | Мінімальний HP/death persistence; не лишати constructor full heal |
| Reward/claim не атомарні | Crash boundary, duplicate event, backup | Whole settlement state, immutable save capture, idempotent application |
| Пізні stage породжують велике дерево claim history | Ledger size/time stress на великому frontier | Монотонний frontier, sparse repeat state, bounded representation |
| Дерево закінчилось задовго до дня 30 | Full purchase timeline/remaining Books | Переналаштувати gates/cost/rewards/R; описати кінцевість дерева, не вигадувати нескінченну прогресію |
| Довгі бої нівелюють travel/boss бонуси | Cycle breakdown й stage wall duration | Equipment/enemy/B tuning окремими profiles |
| Fixed shares дають хибний висновок про баланс | Adaptive/full-focus/omit-one comparisons | Більше релевантних policies і парних seeds, показати межі евристики |

## 18. Порядок реалізації

1. Прийняти baseline етапу 2 без XP/Books-stat maps. Зафіксувати profile, source rewards, seeds/policies і природний Stage 1.
2. Реалізувати catalog, curves, ranks/gates та Books purchase/selection domain. Перевірити власні effects, cap, ціни й failure atomicity.
3. Додати stage attempt lifecycle, snapshot й queued selection. Перевірити clear/death/rest/restart boundaries до включення економічних ефектів.
4. Замінити джерела Books, додати first-clear базу Gold, repeat policy, milestone IDs і єдиний settlement/ledger. Прогнати rewards без активних талантів.
5. Підключити boss damage та crit protection, потім heal, travel й економічні lines. Після кожного кроку — isolated trace зі спільним resolver.
6. Додати мінімальний save/HP contract і реальні restart/crash/backup перевірки. Якщо зміни інтегруються разом з етапом 4, acceptance цих інваріантів усе одно обов'язковий.
7. Побудувати три групи Books UI, rank/selection statuses та reward breakdown. Звірити пояснення контекстів і gates із domain.
8. Оновити runner/audit: незалежні streams, всі 8 combinations, real purchase budgets, adaptive/adversarial policies, open/productive metrics.
9. Провести rule/parity/restart тести й початкові natural прогони. Відокремити hard failures від tuning deviations; обрати придатний спільний профіль.
10. Передати coefficients, results і невирішені KPI у етапи 4–6; desktop оцінку взаємодії залишити явно неперевіреною до етапу 7.

## 19. Критерії приймання

| ID | Критерій | Доказ |
| --- | --- | --- |
| A01 | Усі 6 талантів реалізовані з правильними pair/context IDs | Catalog, T05/T08–T12/T20; базові equipment stats не підмінені |
| A02 | Gates/ціни/ранги/cap працюють без рівня героя | T01–T04/T19; 3 стартові Books купують перший ранг після Stage 1 |
| A03 | Числові прирости спадні, межі finite й явні | T02, reference curve values, profile validation; немає рангу 11 |
| A04 | Books і Gold купують різні можливості | T03/T04/T15; старий Books-stat/drop API відсутній наскрізно |
| A05 | Один талант на пару, snapshot незмінний до clear/death | T05–T07/T21, P01/P03/P05; queued purchase/select і boundary без snapshot працюють за явним порядком |
| A06 | Всі combat/heal/travel ефекти застосовані тільки у своєму контексті | T08–T11/T18/T20; APS=1/rest/crit25% інваріанти збережені |
| A07 | Books переважно за progress; repeat budget не нескінченний | T13–T16, source ledger та finite reserve proof; старий exponential stream відсутній |
| A08 | Reward bases й одноразовість точні | T12–T18/P02/P04; first-clear/milestone/bonus breakdown і no-double-pay |
| A09 | Restart/recovery не змінюють selection/claims або HP без події | P01–P06; наступний runtime settlement після load, не лише JSON round-trip |
| A10 | Domain purchase/select валідовані незалежно від UI | T03–T05/T19; фактичний count/price, no mutation on failure |
| A11 | Runtime/runner використовують ті самі effects/settlement rules | S01–S05, controlled traces, settled boundaries, явні time units |
| A12 | Природний старт і рання помилкова інвестиція мають шлях прогресу | S03/S04; wrong-first-choice/adaptive farm traces без XP й нескінченних Books |
| A13 | Кожен талант має вимірювану природну користь та релевантну альтернативу | Natural contexts, paired effect/investment comparisons, protection lethal-crit evidence |
| A14 | Gold-реінвестиція й усі 8 комбінацій реально досліджені | Source income, matched budgets, purchase/death/rest policies, staged horizon results |
| A15 | Books UI відрізняє owned/next/active та пояснює limits | Manual UI scenarios плюс quote/domain checks; no misleading reward/defense/travel copy |
| A16 | Acceptance report розділяє правила, кандидатний баланс і неперевірені KPI | Profiles/commands/raw results, deviations для етапів 4–6, desktop status |

**Обов'язкове приймання механіки:** A01–A11 і A15 проходять; A12 не залишає доведеного раннього blocker; A13 не має природно мертвої гілки; A14 дає відтворювані результати; A16 чесно позначає межі. Не можна прийняти тільки каталог або формули без snapshot/reward/restart поведінки.

**Балансовий результат цього етапу:** є придатний кандидат, зрозуміло, де виграє кожна альтернатива, як окуповується Gold і де потрібне подальше tuning. Не підтверджувати всі KPI дня 30 без відповідних прогонів. Якщо економіка домінує у всіх перевірених типових контекстах, Books вичерпуються в ранній обов'язковій стіні або protection не має природної користі, це блокер придатного профілю, а не формальна примітка на майбутнє.

**Фінальне приймання V2:** після етапів 5–6 — конкурентний mixed build, користь кожного параметра вище шуму, відсутність універсального гіперфокусу й нескінченного bonus death-farm, прийнятні time-to-purchase/wall/TTK та meaningful choices на день 30. Після етапу 7 — зрозумілий UI й збіг із desktop input/rest. Synthetic докази обмежені заданими профілями й policies.

## 20. Матеріали на виході та статус документа

Каталог/моделі шести талантів; versioned curves/cost/gate/reward profile; stage snapshots і queues; нові Books sources та claim ledger; мінімальний узгоджений save/HP contract; три групи UI й reward breakdown; targeted rule/parity/restart tests; машинозчитувані natural strategy results; acceptance A01–A16 з рекомендаціями для наступних пунктів.

Звіт реалізації вказує commands, ревізію/diff ID, coefficients, reward policy, seed streams, purchase/selection cadence, productive/open hours і невизначеність порівнянь. Математичні приклади не видаються за gameplay-результати.

Під час підготовки прочитано чинні combat/drop/spawner/simulation/persistence механіки й документи попередніх етапів; контрольні криві, суму Books-цін і приклад crit protection обчислено окремо. Gameplay-код не змінено; синтетичні прогони, тести гри й desktop playtest не виконано. Локальні сейви не видалено. Цей документ задає майбутню реалізацію й перевірки.
