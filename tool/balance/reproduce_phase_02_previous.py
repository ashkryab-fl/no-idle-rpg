"""Reproduce the archived pre-phase-02 report without changing live game files."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
from urllib.parse import urljoin

root = Path(__file__).resolve().parents[2]
archive = root / 'docs/balance/phase_02_previous_source.tar.gz'
metadata = json.loads((root / 'docs/balance/phase_02_previous_metadata.json').read_text())
target = root / 'build/phase_02/reproduced_previous'
target.mkdir(parents=True, exist_ok=True)
with tarfile.open(archive) as bundle:
    bundle.extractall(target, filter='data')
for relative, expected in metadata['sha256'].items():
    actual = hashlib.sha256((target / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError(f'Archived source checksum mismatch: {relative}')
config_path = root / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text())
for package in config['packages']:
    package['rootUri'] = (target.as_uri() + '/' if package['name'] == 'idle_companion'
                          else urljoin(config_path.as_uri(), package['rootUri']))
(target / '.dart_tool').mkdir(exist_ok=True)
reproduced_config = target / '.dart_tool/package_config.json'
reproduced_config.write_text(json.dumps(config))
result = subprocess.run([
    'dart', f'--packages={reproduced_config}',
    str(target / 'tool/balance/balance_audit.dart'), '20',
], cwd=root, check=True, capture_output=True, text=True)
report = json.loads(result.stdout)
json.dump(report, sys.stdout)
sys.stdout.write('\n')
