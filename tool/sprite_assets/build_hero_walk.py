#!/usr/bin/env python3
"""Build command for walk; transforms live in the asset manifest."""
try:
    from .build import run_cli
except ImportError:
    from build import run_cli


if __name__ == "__main__":
    run_cli(['tool/sprite_assets/manifests/hero/walk_v2.json'])
