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

Етап 3 — таланти, finite Books, спільний settlement і contextual/funded/matched audits:

```sh
mkdir -p build/phase_03
set -o pipefail
dart compile exe tool/balance/phase_03_audit.dart -o build/phase_03/audit
build/phase_03/audit --seeds 20 --exclude contextual_adaptive | gzip -n > docs/balance/phase_03_baseline.json.gz
build/phase_03/audit --seeds 20 --only contextual_adaptive | gzip -n > docs/balance/phase_03_contextual_adaptive.json.gz
dart run tool/balance/phase_03_traces.dart > docs/balance/phase_03_controlled_traces.json
dart run tool/balance/phase_03_natural_crit.dart > docs/balance/phase_03_natural_crit.json
dart run tool/balance/phase_03_payback.dart > docs/balance/phase_03_payback.json
dart run tool/balance/phase_03_domain_diagnostics.dart > docs/balance/phase_03_domain_diagnostics.json
python3 tool/balance/reproduce_phase_03_previous.py 20 > build/phase_03/previous_reproduced.json
```

[Звіт третього етапу](../docs/phase_03_acceptance_report.md). `simulate_progression.dart` використовує поточні production rules. Старі phase-01/phase-02 entrypoints на актуальному source теж бачать нові правила; історичні звіти відтворюйте з архіву. `reproduce_phase_03_previous.py` перевіряє SHA-256 архівного етапу 2 й запускає його runner; необов’язковий аргумент — число seeds (default 20). [Попередній звіт](../docs/phase_02_acceptance_report.md).

Заморожені поточні результати: `python3 tool/balance/reproduce_phase_03.py audit 20` (також `contextual`, `traces`, `natural-crit`, `payback`, `diagnostics`). Audit JSON збережено в gzip без втрати даних; для перегляду: `gzip -dc docs/balance/phase_03_baseline.json.gz > build/phase_03/baseline.json`.
