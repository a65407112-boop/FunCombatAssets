"""Verify exact original pixels are exported, without repainting the face."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class TextureExportTests(unittest.TestCase):
    def exporter(self):
        path = ROOT / 'Builder/export_head_texture.py'
        self.assertTrue(path.exists(), 'The original texture exporter is missing')
        spec = importlib.util.spec_from_file_location('head_texture_export', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_export_preserves_transparent_rgb_and_skin_independent_rgba(self):
        module = self.exporter()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'face.png'
            image = Image.new('RGBA', (3, 1))
            image.putdata([(0, 0, 0, 0), (0, 0, 0, 0), (255, 20, 60, 128)])
            image.save(path)
            document = module.encode(path.read_bytes(), 'rbxassetid://123')
            self.assertEqual(document['runs'], [[2, 0], [1, 0x803C14FF]])
            pixels = b''.join(color.to_bytes(4, 'little') * count for count, color in document['runs'])
            self.assertEqual(pixels, b'\x00\x00\x00\x00' * 2 + b'\xff\x14\x3c\x80')
            self.assertEqual(document['sourceTexture'], 'rbxassetid://123')
            self.assertEqual((document['width'], document['height']), (3, 1))

    def test_rejects_wrong_original_asset_before_writing_output(self):
        module = self.exporter()
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / 'input.png', Path(tmp) / 'output.json'
            Image.new('RGBA', (1, 1), (255, 255, 255, 255)).save(source)
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                module.export(source, output)
            self.assertFalse(output.exists())

    def test_real_asset_roundtrip_has_original_unmodified_pixels(self):
        module = self.exporter()
        output = ROOT / 'diagnostics/head_texture_130652123696339.json'
        if not output.exists():
            self.fail('The verified original face pixel resource is missing')
        data = json.loads(output.read_text())
        import hashlib
        pixels = b''.join(color.to_bytes(4, 'little') * count for count, color in data['runs'])
        self.assertEqual(hashlib.sha256(pixels).hexdigest(), module.EXPECTED_RGBA_SHA256)
        self.assertEqual(data['sourcePngSha256'], '72bde92df1de980578edbb21f40858771ea7d4cb215a68cd24627d6e4b88e461')

    def test_helper_rejects_output_aliasing_its_source_before_processing(self):
        module = self.exporter()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'original.png'
            path.write_bytes(b'original bytes')
            with self.assertRaisesRegex(ValueError, 'overwrite'):
                module.export(path, path)
            self.assertEqual(path.read_bytes(), b'original bytes')


if __name__ == '__main__':
    unittest.main()
