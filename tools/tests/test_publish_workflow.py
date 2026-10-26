"""Exercise the publication command offline; no Roblox writes are made."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import urllib.error


REPO = Path(__file__).resolve().parents[2]
WORKFLOW = REPO / '.github/workflows/publish-place.yml'


class PublishWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(WORKFLOW.is_file(), 'Manual publication workflow is missing')
        command = textwrap.dedent(WORKFLOW.read_text().split('run: |\n', 1)[1])
        lines = command.strip().splitlines()
        self.assertEqual(lines[0], "python3 - <<'PY'")
        self.assertEqual(lines[-1], 'PY')
        self.code = compile('\n'.join(lines[1:-1]), str(WORKFLOW), 'exec')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = (b'<roblox!\x89\xff\r\n\x1a\n' + struct.pack('<HII8s', 0, 0, 0, bytes(8))
                        + b'END\0' + struct.pack('<III', 0, 9, 0) + b'</roblox>')
        for name, raw in {
            'server/funcombat_server.rbxl': self.payload,
            'config/protocol.json': b'{"version":5,"buildId":"example-build"}',
            'client/example.lua': b'return true\n',
        }.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        self.manifest = {
            'buildId': 'example-build', 'protocolVersion': 5,
            'files': {str(path.relative_to(self.root)): {
                'bytes': path.stat().st_size,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            } for path in self.root.rglob('*') if path.is_file()},
        }
        self.save_manifest()

    def save_manifest(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def execute(self, key='offline-test-key', response=b'{"versionNumber":7}', error=None):
        requests = []

        class Endpoint:
            def open(endpoint, request, timeout):
                requests.append(request)
                if error:
                    raise error
                return io.BytesIO(response)

        output = io.StringIO()
        status = 0
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            with patch.dict(os.environ, {
                'ROBLOX_API_KEY': key,
                'GITHUB_STEP_SUMMARY': str(self.root / 'summary.md'),
            }), patch('sys.path', [str(REPO / 'tools/outfits')] + sys.path), \
                    patch('urllib.request.build_opener', return_value=Endpoint()), \
                    contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                try:
                    exec(self.code, {'__name__': '__main__'})
                except SystemExit as error_exit:
                    status = error_exit.code
        finally:
            os.chdir(previous)
        return status, output.getvalue(), requests

    def test_publishes_verified_bytes_to_the_selected_game(self):
        status, output, requests = self.execute()
        self.assertEqual(status, 0, output)
        self.assertEqual(len(requests), 1)
        request = requests[0]
        self.assertEqual(request.full_url, 'https://apis.roblox.com/universes/v1/10767751574/places/80093785985728/versions?versionType=Published')
        self.assertEqual(request.method, 'POST')
        self.assertEqual(request.data, self.payload)
        self.assertEqual(request.get_header('Content-type'), 'application/octet-stream')
        self.assertEqual(request.get_header('X-api-key'), 'offline-test-key')
        self.assertNotIn('offline-test-key', output)
        self.assertIn('version 7', output)
        self.assertIn('version 7', (self.root / 'summary.md').read_text())

    def test_missing_secret_does_not_publish(self):
        status, output, requests = self.execute(key='')
        self.assertNotEqual(status, 0)
        self.assertIn('ROBLOX_API_KEY', str(status) + output)
        self.assertEqual(requests, [])

    def test_modified_client_stops_publication(self):
        (self.root / 'client/example.lua').write_text('return false\n')
        status, output, requests = self.execute()
        self.assertNotEqual(status, 0)
        self.assertIn('client/example.lua', str(status) + output)
        self.assertEqual(requests, [])

    def test_invalid_scalar_type_stops_even_with_a_matching_manifest(self):
        def string(value):
            raw = value.encode()
            return struct.pack('<I', len(raw)) + raw

        def chunk(name, body):
            return name + struct.pack('<III', 0, len(body), 0) + body

        raw = b'<roblox!\x89\xff\r\n\x1a\n' + struct.pack('<HII8s', 0, 1, 1, bytes(8))
        raw += chunk(b'INST', struct.pack('<I', 0) + string('HumanoidDescription') + b'\0' + struct.pack('<I', 1) + bytes(4))
        raw += chunk(b'PROP', struct.pack('<I', 0) + string('BodyTypeScale') + b'\x05' + struct.pack('<d', 0.5))
        raw += chunk(b'END\0', b'</roblox>')
        (self.root / 'server/funcombat_server.rbxl').write_bytes(raw)
        self.manifest['files']['server/funcombat_server.rbxl'] = {
            'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
        }
        self.save_manifest()
        status, output, requests = self.execute()
        self.assertNotEqual(status, 0)
        self.assertIn('HumanoidDescription.BodyTypeScale', str(status) + output)
        self.assertEqual(requests, [])

    def test_mismatched_build_stops_publication(self):
        self.manifest['buildId'] = 'different-build'
        self.save_manifest()
        status, output, requests = self.execute()
        self.assertNotEqual(status, 0)
        self.assertEqual(requests, [])

    def test_api_rejection_is_reported_without_secret_or_retry(self):
        error = urllib.error.HTTPError('https://apis.roblox.com/', 403, 'Forbidden', {}, io.BytesIO(b'offline-test-key'))
        status, output, requests = self.execute(error=error)
        self.assertNotEqual(status, 0)
        self.assertIn('403', str(status) + output)
        self.assertNotIn('offline-test-key', str(status) + output)
        self.assertEqual(len(requests), 1)

    def test_unconfirmed_response_is_not_reported_as_success(self):
        status, output, requests = self.execute(response=b'{"message":"unexpected"}')
        self.assertNotEqual(status, 0)
        self.assertNotIn('Published', output)
        self.assertEqual(len(requests), 1)
        self.assertFalse((self.root / 'summary.md').exists())


if __name__ == '__main__':
    unittest.main()
