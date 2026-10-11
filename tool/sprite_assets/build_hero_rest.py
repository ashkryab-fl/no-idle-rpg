#!/usr/bin/env python3
"""Build command for rest; transforms live in the asset manifest."""
try:
    from .build import run_cli
except ImportError:
    from build import run_cli


if __name__ == "__main__":
    run_cli(['tool/sprite_assets/manifests/hero/seated_v1.json', 'tool/sprite_assets/manifests/hero/sit_down_v1.json', 'tool/sprite_assets/manifests/hero/sharpen_v1.json'])
