#!/usr/bin/env python3
"""Build PNGs and world-scale transition previews from versioned manifests."""
import argparse
from pathlib import Path

try:
    from .pipeline import ROOT, build_manifest, build_previews, preview_data, selected_manifests
    from .verify import verify_manifest, verify_previews
except ImportError:
    from pipeline import ROOT, build_manifest, build_previews, preview_data, selected_manifests
    from verify import verify_manifest, verify_previews


def run_cli(manifests=None):
    parser = argparse.ArgumentParser(description=__doc__)
    if manifests is None:
        parser.add_argument('manifests', nargs='*')
    parser.add_argument('--output-root', type=Path, help='Write into a separate tree; sources remain in the repository')
    parser.add_argument('--no-previews', action='store_true')
    parser.add_argument('--previews-only', action='store_true', help='Render previews from Dart content without rebuilding PNGs')
    parser.add_argument('--verify', '--check', action='store_true', dest='verify')
    args = parser.parse_args()
    output = args.output_root.resolve() if args.output_root else ROOT
    if args.previews_only:
        build_previews(preview_data(), ROOT, output)
        return
    for path in selected_manifests(manifests if manifests is not None else args.manifests):
        if args.verify:
            verify_manifest(path, output_root=output)
        else:
            build_manifest(path, output_root=output, previews=not args.no_previews)
            verify_manifest(path, output_root=output, rebuild=False, previews=not args.no_previews)

    if manifests is None and not args.manifests and not args.verify and not args.no_previews:
        data = preview_data('art/hero/rest_variants_v1')
        build_previews(data, ROOT, output)
        verify_previews(data, output_root=output)


if __name__ == '__main__':
    run_cli()
