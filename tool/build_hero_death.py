#!/usr/bin/env python3
"""Compatibility command for death; transforms live in the asset manifest."""
from sprite_assets.build import run_cli


if __name__ == "__main__":
    run_cli(['art/hero/death_v1/manifest.json'])
