#!/usr/bin/env python3
"""Compatibility command for rest; transforms live in the asset manifest."""
from sprite_assets.build import run_cli


if __name__ == "__main__":
    run_cli(['art/hero/seated_v1/manifest.json', 'art/hero/sit_down_v1/manifest.json', 'art/hero/sharpen_v1/manifest.json'])
