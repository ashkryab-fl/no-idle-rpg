"""Run a frozen phase-03 report with verified source, without touching live saves."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
from urllib.parse import urljoin

root = Path(__file__).resolve().parents[2]
metadata = json.loads((root / 'docs/balance/phase_03_source_metadata.json').read_text())
target = root / '.dart_tool/phase_03/reproduced_current'
target.mkdir(parents=True, exist_ok=True)
with tarfile.open(root / 'docs/balance/phase_03_source.tar.gz') as bundle:
    bundle.extractall(target, filter='data')
for relative, expected in metadata['sha256'].items():
    if hashlib.sha256((target / relative).read_bytes()).hexdigest() != expected:
        raise RuntimeError(f'Archived source checksum mismatch: {relative}')
config_path = root / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text())
for package in config['packages']:
    package['rootUri'] = (target.as_uri() + '/' if package['name'] == 'idle_companion'
                          else urljoin(config_path.as_uri(), package['rootUri']))
(target / '.dart_tool').mkdir(exist_ok=True)
reproduced_config = target / '.dart_tool/package_config.json'
reproduced_config.write_text(json.dumps(config))
kind = sys.argv[1] if len(sys.argv) > 1 else 'audit'
seeds = sys.argv[2] if len(sys.argv) > 2 else '20'
reports = {
    'audit': ('phase_03_audit.dart', ['--seeds', seeds, '--exclude', 'contextual_adaptive']),
    'contextual': ('phase_03_audit.dart', ['--seeds', seeds, '--only', 'contextual_adaptive']),
    'traces': ('phase_03_traces.dart', []),
    'natural-crit': ('phase_03_natural_crit.dart', []),
    'payback': ('phase_03_payback.dart', []),
    'diagnostics': ('phase_03_domain_diagnostics.dart', []),
}
entrypoint, options = reports[kind]
subprocess.run(['dart', f'--packages={reproduced_config}',
                str(target / 'tool/balance' / entrypoint), *options], cwd=root, check=True)
