"""Regressions for the Studio BodyTypeScale format-5/format-4 failure."""
from pathlib import Path
import struct
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Builder'))
sys.path.insert(0, str(ROOT / 'tools/outfits'))
import model_io
from native_r6_upgrade import saved_rig


def fixture(property_type):
    def string(value):
        raw = value.encode()
        return struct.pack('<I', len(raw)) + raw

    def chunk(name, body):
        return name + struct.pack('<III', 0, len(body), 0) + body

    header = b'<roblox!\x89\xff\r\n\x1a\n' + struct.pack('<HII8s', 0, 1, 1, bytes(8))
    instance = struct.pack('<I', 0) + string('HumanoidDescription') + b'\0' + struct.pack('<I', 1) + bytes(4)
    payload = struct.pack('<d', 0.5) if property_type == 5 else bytes.fromhex('7e000000')
    prop = struct.pack('<I', 0) + string('BodyTypeScale') + bytes([property_type]) + payload
    return header + chunk(b'INST', instance) + chunk(b'PROP', prop) + chunk(b'END\0', b'</roblox>')


class SavedNumericTypesTests(unittest.TestCase):
    def rig(self, classname, properties, schema=None):
        data = {'root': 1, 'nodes': [{'id': 1, 'class': classname, 'name': 'Fixture',
                                    'properties': properties}]}
        return saved_rig(data, 'numeric-regression', schema)[0]

    def test_description_scales_use_float_when_class_is_absent_from_source(self):
        # The old server had no saved HumanoidDescription class, so source-based
        # tag inference could not resolve these newly reconstructed properties.
        names = ['BodyTypeScale', 'DepthScale', 'HeadScale', 'HeightScale', 'ProportionScale', 'WidthScale']
        model = self.rig('HumanoidDescription', {name: {'type': 'number', 'value': 0.5} for name in names})
        for name in names:
            prop = model.find(f'Properties/*[@name="{name}"]')
            self.assertEqual(prop.tag, 'float', name)
            self.assertEqual(float(prop.text), 0.5)

    def test_existing_bad_double_tag_does_not_survive_a_rebuild(self):
        model = self.rig('HumanoidDescription', {'BodyTypeScale': {'type': 'number', 'value': 0.25}},
                         {'HumanoidDescription': {'BodyTypeScale': 'double'}})
        self.assertEqual(model.find('Properties/*[@name="BodyTypeScale"]').tag, 'float')

    def test_native_double_value_keeps_double_precision(self):
        model = self.rig('NumberValue', {'Value': {'type': 'number', 'value': 1.0000000000000002}},
                         {'NumberValue': {'Value': 'double'}})
        prop = model.find('Properties/*[@name="Value"]')
        self.assertEqual(prop.tag, 'double')
        self.assertEqual(float(prop.text), 1.0000000000000002)

    def test_unknown_numeric_storage_type_fails_instead_of_guessing(self):
        with self.assertRaisesRegex(ValueError, 'numeric.*type'):
            self.rig('FutureClass', {'NewScale': {'type': 'number', 'value': 0.5}})

    def test_binary_guard_rejects_the_studio_failure(self):
        self.assertTrue(callable(getattr(model_io, 'validate_saved_scalar_types', None)),
                        'Missing engine scalar-type validation')
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'bad.rbxl'
            binary.write_bytes(fixture(5))
            with self.assertRaisesRegex(ValueError, 'HumanoidDescription.BodyTypeScale'):
                model_io.validate_saved_scalar_types(binary)

    def test_binary_guard_accepts_native_float_storage(self):
        self.assertTrue(callable(getattr(model_io, 'validate_saved_scalar_types', None)),
                        'Missing engine scalar-type validation')
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'good.rbxl'
            binary.write_bytes(fixture(4))
            report = model_io.validate_saved_scalar_types(binary)
            self.assertTrue(report['passed'])
            self.assertEqual(report['propertiesChecked'], 1)


if __name__ == '__main__':
    unittest.main()
