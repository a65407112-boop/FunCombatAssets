"""Native service flags are separate from property types and instance names."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'outfits'))
import model_io

def chunk(tag,body):return tag+struct.pack('<III',0,len(body),0)+body
def string(value):
    raw=value.encode();return struct.pack('<I',len(raw))+raw
def refs(values):
    previous=0;encoded=[]
    for value in values:
        delta=value-previous;previous=value;encoded.append(struct.pack('>I',(delta<<1)^(delta>>31)))
    return bytes(value[plane] for plane in range(4) for value in encoded)
def fixture(service):
    raw=b'<roblox!\x89\xff\r\n\x1a\n'+struct.pack('<HII8s',0,3,3,bytes(8))
    for i,name in enumerate(['Workspace','ServerScriptService','Part']):
        enabled=service and i<2
        raw+=chunk(b'INST',struct.pack('<I',i)+string(name)+bytes([enabled])+struct.pack('<I',1)+refs([i])+(b'\1' if enabled else b''))
    raw+=chunk(b'PROP',struct.pack('<I',2)+string('Name')+b'\1'+string('opaque_floor'))
    raw+=chunk(b'PRNT',b'\0'+struct.pack('<I',3)+refs([0,1,2])+refs([-1,-1,0]))
    return raw+chunk(b'END\0',b'</roblox>')

class PlaceServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'place.rbxl'
        self.expected={'Workspace','ServerScriptService'}

    def test_plain_instances_do_not_count_as_services(self):
        self.path.write_bytes(fixture(False))
        with self.assertRaisesRegex(ValueError,'Workspace|ServerScriptService'):
            model_io.validate_place_services(self.path,self.expected)

    def test_service_flags_survive_a_lossless_repair(self):
        original=fixture(False);self.path.write_bytes(original)
        result=model_io.repair_place_services(self.path,self.expected)
        self.assertEqual(result['chunksChanged'],2)
        self.assertEqual(model_io.validate_place_services(self.path,self.expected)['servicesChecked'],2)
        self.assertEqual([body for tag,body in model_io.binary_chunks(self.path) if tag!=b'INST'],
                         [struct.pack('<I',2)+string('Name')+b'\1'+string('opaque_floor'),
                          b'\0'+struct.pack('<I',3)+refs([0,1,2])+refs([-1,-1,0]),b'</roblox>'])
        nodes=model_io.source_strings(self.path)
        self.assertFalse(nodes[2]['service'])

    def test_already_valid_services_are_not_rewritten(self):
        original=fixture(True);self.path.write_bytes(original)
        self.assertEqual(model_io.repair_place_services(self.path,self.expected)['chunksChanged'],0)
        self.assertEqual(self.path.read_bytes(),original)

    def test_missing_required_service_is_rejected(self):
        self.path.write_bytes(fixture(True))
        with self.assertRaisesRegex(ValueError,'ServerStorage'):
            model_io.validate_place_services(self.path,{'ServerStorage'})

    def test_service_without_root_parent_record_is_rejected(self):
        raw=fixture(True)
        parent_chunk=chunk(b'PRNT',b'\0'+struct.pack('<I',3)+refs([0,1,2])+refs([-1,-1,0]))
        self.path.write_bytes(raw.replace(parent_chunk,b''))
        with self.assertRaises(ValueError):model_io.validate_place_services(self.path,self.expected)

if __name__=='__main__':unittest.main()
