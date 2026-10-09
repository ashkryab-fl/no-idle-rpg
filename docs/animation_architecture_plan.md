# План завершення рефакторингу системи анімацій

Оновлено 2026-10-09. У плані залишено незавершені етапи 4–5 та перевірки,
для яких ще немає evidence. Поточний playback не персиститься; міграція saves
не потрібна.

## Ціль і контракти

Нова сидяча активність, вставання чи розгалуження додається ресурсами й графом,
без змін універсального runner, coordinator або renderer.

Зберігати pure Dart core/domain; завершення encounter перед відпочинком;
блокування distance/scroll/spawn до `readyToTravel`; непреривне сідання;
одноразовий intro; damage із clip marker; незалежний hit overlay;
фінальний death hold; однаковий результат при різних FPS і швидкостях.
Shared seated pose і ground/head scale на стиках мають залишатися незмінними.

## 4. Контент і asset pipeline

- Розділити встановлені hero resources на poses/clips/variants. Для PNG ворогів
  створювати каталоги лише коли є реальні assets; наявний Canvas renderer має
  окремий явний procedural timeline, без фальшивих sprite-визначень.
- Оформити каталоги variant IDs і metadata з entry/exit pose contracts,
  дозволеними умовами, вагами, explicit cooldown key та started/completed timing.
  Один clip можна використовувати в різних nodes без неявного спільного cooldown.
- Для cooldown-limited fallback підключити сигнал retry при зміні eligibility.
  Selection лишається лише на вході в Select; fallback не перезаходить у HoldPose
  і не запускає lottery кожного кадру.
- Створити один manifest для source rectangles/order, спільного source scale,
  frame translations, rig, output frames/atlas, alpha і preview sequence.
- Реалізувати `tool/sprite_assets/build.py` та `verify.py`; поточні окремі
  `build_hero_*.py` залишити thin wrappers над спільним builder.
- Перевіряти exact sheet cells, прозорі margins, незмінність shared resource
  і transitions у фактичному world scale. Не fit-ити кадри незалежно за bbox.
- Зберігати первинні front/back/side references, точні prompts та selected raw
  output. Pose-family validation не замінює візуальну перевірку нового стику.
- Продемонструвати друге вставання і другу seated activity як новий опис/арт,
  із cleanup назад у `seatedNeutral`, якщо кінцева поза активності відрізняється.

Критерій: новий variant додається лише контентом/артом; wrappers відтворюють
поточні PNG; builder/verify і transition previews мають відтворювані команди.

Запланована розкладка:

```text
lib/content/animations/
  hero/{poses,clips,rest_graphs,variants}.dart
  enemies/{procedural_timelines,<authored-enemy>}.dart
tool/sprite_assets/{build,verify}.py
art/hero/<version>/manifest.json
```

Content залишається typed Dart. JSON використовується для asset manifest;
перенесення графів у JSON/YAML — окрема робота лише за потреби редактора
або runtime loading. Не створювати placeholder замість відсутнього artwork.

## 5. Завершення міграції

- Перевести решту callers/tests на `PlaybackSnapshot`, typed resources і graphs.
  Прибрати presentation aliases `heroAnimation/Elapsed`, `enemyAnimation/Elapsed`
  та HoldPose → legacy clip ID mapping; поза вже рендериться через FrameId.
- Видалити `IdleBehaviorSystem` compatibility alias, `IdleAnimationDefinition`,
  `LegacyIdleBehaviorSystem`, deprecated nextAnimationId/nextAnimationIds,
  legacy exit sequences і `caughtRemaining` compatibility delay.
- Видалити `AnimationCatalog` / `AnimationDefinition` adapters та silent
  unknown-ID string lookup. Debug frames дозволяти лише явним test/debug content.
- Прибрати obsolete fixtures/compatibility tests після перенесення корисних
  asset/timeline/geometry regressions на кінцевий API.
- Оновити README, authoring docs та tests навколо фінальної архітектури.

Критерій: немає legacy програвача чи silent unknown-ID fallback; production
renderer лише малює resolved snapshot; кадри, таймінг, marker events і пріоритети
мають одного owner. Смерть/reset скасовують pending signals; async image loading
не підміняє актуальну generation playback.

## Перевірки, що залишаються

- Live desktop playback: сідання → static hold → sharpen intro/loop → neutral
  hold → усі 6 кадрів вставання → walk; повторні activity samples, нова inactivity
  посеред exit, смерть/reset, повернення після encounter/reward.
- Візуальні ground/head scale і плавність усіх поточних та нових стиків у грі.
  Widget pixel regression уже перевіряє незмінність shared sit hold; live
  перевірка в native desktop window для цієї міграції ще не проводилась.
- Native alpha/click-through на macOS; build/runtime і DPI/transparency на Windows
  потребують відповідного host. Build для поточної інтеграції ще не запускався.
- Після змін етапів 4–5 повторити graph/variant/marker tests, 30/60 FPS × x1/x5/x20,
  великі/partitioned dt, reset/death, headless combat outcomes, real-asset cache
  loading і transition pixel regressions. Не позначати live/platform перевірки
  успішними за результатом static analysis або widget tests.
