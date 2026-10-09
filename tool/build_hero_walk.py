#!/usr/bin/env python3
"""Compatibility command for walk; transforms live in the asset manifest."""
from sprite_assets.build import run_cli


if __name__ == "__main__":
    run_cli(['art/hero/walk_v2/manifest.json'])
