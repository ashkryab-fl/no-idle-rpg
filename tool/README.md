# Інструменти розробки

Усі команди запускаються з кореня репозиторію.

| Папка | Призначення |
| --- | --- |
| `balance/` | Симуляція прогресії та аудит ігрового балансу. |
| `sprite_assets/` | Складання й перевірка спрайтів, рецепти у `manifests/hero/`, експорт даних для прев’ю. |

Приклади запуску:

```sh
dart run tool/balance/simulate_progression.dart --days 30 --hours-per-day 7 --seeds 20
dart run tool/balance/balance_audit.dart 20
python3 tool/sprite_assets/build_hero_walk.py --check
python3 tool/sprite_assets/build.py --help
python3 -m unittest tool.sprite_assets.test_pipeline
dart run tool/sprite_assets/export_animation_previews.dart
```

Деталі складання та перевірки спрайтів: [sprite_assets/README.md](sprite_assets/README.md).

Звіт першого етапу та правила productive time: [phase_01_acceptance_report.md](../docs/phase_01_acceptance_report.md). Історичний baseline відтворює `python3 tool/balance/reproduce_phase_01_legacy.py`; він працює з архівною копією під `build/`, без зміни production-коду й сейвів.

Етап 2 — Gold-only curves, isolated profiles і source-specific income stress:

```sh
dart run tool/balance/phase_02_audit.dart 20 > docs/balance/phase_02_baseline.json
dart run tool/balance/phase_02_curve_audit.dart > docs/balance/phase_02_curves.json
dart run tool/balance/phase_02_trace.dart > docs/balance/phase_02_controlled_traces.json
dart run tool/balance/phase_02_purchase_diagnostics.dart > docs/balance/phase_02_purchase_diagnostics.json
python3 tool/balance/reproduce_phase_02_previous.py > build/phase_02/previous_reproduced.json
```

[Звіт другого етапу](../docs/phase_02_acceptance_report.md). `balance_audit.dart` і `simulate_progression.dart` використовують поточний production-профіль; історичні результати відтворюються тільки з архіву через відповідний Python helper.
