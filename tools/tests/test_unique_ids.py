"""Saved instance identities must be unique across the entire DataModel."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'outfits'))
import model_io
from test_place_services import chunk,string,refs

IDS=[bytes.fromhex(value) for value in (
    '00000001000000020000000000000006',
    '00000002000000020000000000000008',
    '0000000300000002000000000000000a',
    '0000000400000002000000000000000c',
    '0000000500000002000000000000000e',
    '00000006000000020000000000000010')]

def fixture(duplicate=False,zero=False,missing=False):
    groups=[('Workspace',[0]),('Configuration',[1]),('BoolValue',[2]),('Part',[3,4]),('ModuleScript',[5])]
    raw=b'<roblox!\x89\xff\r\n\x1a\n'+struct.pack('<HII8s',0,5,6,bytes(8))
    for cid,(name,owners) in enumerate(groups):
        raw+=chunk(b'INST',struct.pack('<I',cid)+string(name)+b'\0'+struct.pack('<I',len(owners))+refs(owners))
    values=list(IDS)
    if duplicate:values[2]=values[1]
    if zero:values[3]=bytes(16)
    for cid,(_,owners) in enumerate(groups):
        if missing and cid==4:continue
        payload=bytes(values[owner][plane] for plane in range(16) for owner in owners)
        raw+=chunk(b'PROP',struct.pack('<I',cid)+string('UniqueId')+b'\x1f'+payload)
    # HistoryId is unrelated metadata and can legitimately repeat zero.
    raw+=chunk(b'PROP',struct.pack('<I',3)+string('HistoryId')+b'\x1f'+bytes(32))
    raw+=chunk(b'PROP',struct.pack('<I',4)+string('Source')+b'\1'+string('return 42'))
    raw+=chunk(b'PRNT',b'\0'+struct.pack('<I',6)+refs(range(6))+refs([-1,0,1,0,0,0]))
    return raw+chunk(b'END\0',b'</roblox>')

def identities(path):
    """Independent fixture decoder for the assertions, not the repair helpers."""
    result={}
    counts={0:1,1:1,2:1,3:2,4:1}
    owners={0:[0],1:[1],2:[2],3:[3,4],4:[5]}
    for tag,body in model_io.binary_chunks(path):
        if tag!=b'PROP':continue
        r=model_io.Reader(body);cid=r.u32();name=r.string();kind=r.read(1)[0]
        if name!=b'UniqueId':continue
        assert kind==31
        data=r.read(counts[cid]*16)
        for i,owner in enumerate(owners[cid]):
            result[owner]=bytes(data[plane*counts[cid]+i] for plane in range(16))
    return result

def unrelated_chunks(path):
    raw=Path(path).read_bytes();offset=32;result=[]
    for tag,body in model_io.binary_chunks(path):
        _,compressed,length,_=struct.unpack_from('<4sIII',raw,offset)
        end=offset+16+(compressed or length)
        is_identity=False
        if tag==b'PROP':
            reader=model_io.Reader(body);reader.u32();is_identity=reader.string()==b'UniqueId'
        if not is_identity:result.append(raw[offset:end])
        offset=end
    return result

class UniqueIdTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'place.rbxl'

    def test_unique_values_across_interleaved_classes_are_accepted(self):
        self.path.write_bytes(fixture())
        self.assertEqual(model_io.validate_saved_unique_ids(self.path)['instancesChecked'],6)

    def test_duplicate_identity_across_different_classes_is_rejected(self):
        self.path.write_bytes(fixture(duplicate=True))
        with self.assertRaisesRegex(ValueError,'Duplicate UniqueId'):
            model_io.validate_saved_unique_ids(self.path)

    def test_zero_identity_is_rejected(self):
        self.path.write_bytes(fixture(zero=True))
        with self.assertRaisesRegex(ValueError,'Zero UniqueId'):
            model_io.validate_saved_unique_ids(self.path)

    def test_missing_class_identity_table_is_rejected(self):
        self.path.write_bytes(fixture(missing=True))
        with self.assertRaisesRegex(ValueError,'Missing UniqueId'):
            model_io.validate_saved_unique_ids(self.path)

    def test_repair_preserves_valid_ids_and_every_unrelated_raw_chunk(self):
        original=fixture(duplicate=True,zero=True,missing=True);self.path.write_bytes(original)
        before=unrelated_chunks(self.path)
        result=model_io.repair_saved_unique_ids(self.path)
        actual=identities(self.path)
        self.assertEqual([actual[i] for i in (0,1,4)],[IDS[i] for i in (0,1,4)])
        self.assertEqual(len(set(actual.values())),6)
        self.assertNotIn(bytes(16),actual.values())
        self.assertEqual(result['idsAssigned'],3)
        self.assertEqual(result['zeroIdsReplaced'],1)
        self.assertEqual(result['duplicateIdsReplaced'],1)
        self.assertEqual(result['missingIdsAdded'],1)
        self.assertEqual(self.path.read_bytes()[:32],original[:32])
        self.assertEqual(unrelated_chunks(self.path),before)

    def test_valid_file_is_not_rewritten(self):
        original=fixture();self.path.write_bytes(original)
        self.assertEqual(model_io.repair_saved_unique_ids(self.path)['idsAssigned'],0)
        self.assertEqual(self.path.read_bytes(),original)

    def test_repair_is_idempotent(self):
        self.path.write_bytes(fixture(duplicate=True,zero=True,missing=True))
        model_io.repair_saved_unique_ids(self.path);once=self.path.read_bytes()
        self.assertEqual(model_io.repair_saved_unique_ids(self.path)['idsAssigned'],0)
        self.assertEqual(self.path.read_bytes(),once)

    def test_wrong_native_identity_type_is_rejected_without_modifying_the_file(self):
        original=fixture().replace(string('UniqueId')+b'\x1f',string('UniqueId')+b'\x05',1)
        self.path.write_bytes(original)
        with self.assertRaisesRegex(ValueError,'UniqueId.*type'):
            model_io.repair_saved_unique_ids(self.path)
        self.assertEqual(self.path.read_bytes(),original)

if __name__=='__main__':unittest.main()
