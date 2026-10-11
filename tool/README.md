# Інструменти розробки

Усі команди запускаються з кореня репозиторію.

| Папка | Призначення |
| --- | --- |
| `balance/` | Симуляція прогресії та аудит ігрового балансу. |
| `sprite_assets/` | Складання й перевірка спрайтів, рецепти у `manifests/hero/`, експорт даних для прев’ю. |

Приклади запуску:

```sh
dart run tool/balance/simulate_progression.dart --days 30 --hours-per-day 8 --seeds 3
dart run tool/balance/balance_audit.dart 20
python3 tool/sprite_assets/build_hero_walk.py --check
python3 tool/sprite_assets/build.py --help
python3 -m unittest tool.sprite_assets.test_pipeline
dart run tool/sprite_assets/export_animation_previews.dart
```

Деталі складання та перевірки спрайтів: [sprite_assets/README.md](sprite_assets/README.md).
