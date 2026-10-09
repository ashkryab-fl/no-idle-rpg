#!/usr/bin/env python3
"""Compatibility command for stand_up; transforms live in the asset manifest."""
from sprite_assets.build import run_cli


if __name__ == "__main__":
    run_cli(['art/hero/stand_up_v1/manifest.json'])
