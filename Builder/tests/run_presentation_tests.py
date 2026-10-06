"""Run the real presentation factories with engine-only test doubles.

These checks cover layering, frame ordering, warm caches and grip transforms.
They cannot validate Roblox animation playback, asset permissions or physics.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = 'local cleanupFactory, assetsFactory, animationsFactory, weaponsFactory, preloadFactory, charactersFactory\n'
code += (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
for name in ['cleanup', 'assets', 'animations', 'weapons', 'preload', 'characters']:
    path = ROOT / 'client' / (name + '.lua')
    body = path.read_text() if path.exists() else 'return nil'
    code += '\n' + name + 'Factory=(function()\n' + body + '\nend)()\n'
code += (ROOT / 'Builder/tests/presentation_checks.spec.luau').read_text()
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'presentation.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
