# План завершення рефакторингу системи анімацій

Оновлено 2026-10-09. У плані залишено незавершений етап 5 та перевірки,
для яких ще немає evidence. Контент/pipeline описані в `docs/hero_rest.md`
і `tool/sprite_assets/README.md`. Поточний playback не персиститься;
міграція saves не потрібна.

## Ціль і контракти

Нова сидяча активність, вставання чи розгалуження додається ресурсами й графом,
без змін універсального runner, coordinator або renderer.

Зберігати pure Dart core/domain; завершення encounter перед відпочинком;
блокування distance/scroll/spawn до `readyToTravel`; непреривне сідання;
одноразовий intro; damage із clip marker; незалежний hit overlay;
фінальний death hold; однаковий результат при різних FPS і швидкостях.
Shared seated pose і ground/head scale на стиках мають залишатися незмінними.

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
- Після завершення етапу 5 повторити graph/variant/marker tests, 30/60 FPS × x1/x5/x20,
  великі/partitioned dt, reset/death, headless combat outcomes, real-asset cache
  loading і transition pixel regressions. Не позначати live/platform перевірки
  успішними за результатом static analysis або widget tests.
