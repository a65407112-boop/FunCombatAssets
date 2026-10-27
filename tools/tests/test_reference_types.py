"""Detect wrongly typed native references independently of names/services."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from lxml import etree as E

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'outfits'))
import model_io
from test_place_services import chunk,string,refs

SCHEMA={'parents':{'Workspace':'Instance','Model':'Instance','Part':'BasePart',
    'BasePart':'Instance','ObjectValue':'Instance','Instance':'<<<ROOT>>>'},
    'properties':{'Model':{'PrimaryPart':'BasePart'},'ObjectValue':{'Value':'Instance'}}}

def fixture(target):
    raw=b'<roblox!\x89\xff\r\n\x1a\n'+struct.pack('<HII8s',0,4,4,bytes(8))
    for i,name in enumerate(['Workspace','Model','Part','ObjectValue']):
        raw+=chunk(b'INST',struct.pack('<I',i)+string(name)+b'\0'+struct.pack('<I',1)+refs([i]))
    raw+=chunk(b'PROP',struct.pack('<I',1)+string('PrimaryPart')+b'\x13'+refs([target]))
    raw+=chunk(b'PROP',struct.pack('<I',3)+string('Value')+b'\x13'+refs([0]))
    return raw+chunk(b'PRNT',b'\0'+struct.pack('<I',4)+refs([0,1,2,3])+refs([-1,0,1,0]))+chunk(b'END\0',b'</roblox>')

class ReferenceTypeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'place.rbxl'

    def test_workspace_is_rejected_as_model_primary_part(self):
        self.path.write_bytes(fixture(0))
        with self.assertRaisesRegex(ValueError,'Model.PrimaryPart.*BasePart.*Workspace'):
            model_io.validate_saved_reference_types(self.path,SCHEMA)

    def test_a_part_subclass_is_accepted_and_workspace_is_a_valid_generic_instance(self):
        self.path.write_bytes(fixture(2))
        result=model_io.validate_saved_reference_types(self.path,SCHEMA)
        self.assertEqual(result['referencesChecked'],2)
        self.assertEqual(result['nonNullTargetsChecked'],2)

    def test_null_primary_part_is_accepted(self):
        self.path.write_bytes(fixture(-1))
        self.assertEqual(model_io.validate_saved_reference_types(self.path,SCHEMA)['nonNullTargetsChecked'],1)

    def test_dangling_reference_is_rejected(self):
        self.path.write_bytes(fixture(999))
        with self.assertRaisesRegex(ValueError,'unresolved'):
            model_io.validate_saved_reference_types(self.path,SCHEMA)

    def test_missing_reference_defaults_are_explicit_nulls_without_overwriting_existing_targets(self):
        tree=E.fromstring(b'<roblox><Item class="Model"><Properties><Ref name="PrimaryPart">floor</Ref></Properties></Item><Item class="Model"><Properties><string name="Name">room</string></Properties></Item></roblox>')
        self.assertEqual(model_io.complete_reference_properties(tree),1)
        models=tree.findall('Item')
        self.assertEqual(models[0].findtext('Properties/Ref[@name="PrimaryPart"]'),'floor')
        self.assertEqual(models[1].findtext('Properties/Ref[@name="PrimaryPart"]'),'null')

if __name__=='__main__':unittest.main()
