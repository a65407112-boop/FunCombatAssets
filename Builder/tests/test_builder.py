import hashlib, importlib.util, pathlib, struct, tempfile, unittest
from lxml import etree as E

BASE=pathlib.Path(__file__).resolve().parents[1]

def binary_type_fixture(team_color=11, value=27):
    def string(text):
        raw=text.encode();return struct.pack('<I',len(raw))+raw
    def chunk(name,body):return name+struct.pack('<III',0,len(body),0)+body
    header=b'<roblox!\x89\xff\r\n\x1a\n'+struct.pack('<HII8s',0,2,2,b'\0'*8)
    data=header
    for index,classname in enumerate(['SpawnLocation','IntValue']):
        data+=chunk(b'INST',struct.pack('<I',index)+string(classname)+b'\0'+struct.pack('<I',1)+(index*2).to_bytes(4,'big'))
    data+=chunk(b'PROP',struct.pack('<I',0)+string('TeamColor')+bytes([team_color])+(194 if team_color==11 else 388).to_bytes(4,'big'))
    data+=chunk(b'PROP',struct.pack('<I',1)+string('Value')+bytes([value])+(8).to_bytes(8 if value==27 else 4,'big'))
    return data

class BuilderTests(unittest.TestCase):
    def load(self):
        spec=importlib.util.spec_from_file_location('builder',BASE/'build.py')
        m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
    def test_builder_exists(self):
        self.assertTrue((BASE/'build.py').is_file(), 'Source-specific builder is missing')

    def test_input_cannot_be_overwritten_by_output(self):
        spec=importlib.util.spec_from_file_location('builder',BASE/'build.py')
        self.assertIsNotNone(spec)
        if not (BASE/'build.py').exists(): self.fail('Builder does not exist')
        m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            source=pathlib.Path(d)/'input.rbxl';source.write_bytes(b'original')
            with self.assertRaises(ValueError):m.safe_output(source,pathlib.Path(d))
            self.assertEqual(source.read_bytes(),b'original')
    def test_recursive_output_rejected(self):
        m=self.load()
        with self.assertRaises(ValueError):m.safe_output(BASE/'some_input.rbxl',m.ROOT/'output')
    def test_other_source_rejected_before_writing(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            source=pathlib.Path(d)/'wrong.rbxl';source.write_bytes(b'original')
            output=pathlib.Path(d)/'build'
            with self.assertRaisesRegex(ValueError,'checksum mismatch'):m.build(source,'not-required',output)
            self.assertFalse(output.exists());self.assertEqual(source.read_bytes(),b'original')
    def test_archives_are_deterministic(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            root=pathlib.Path(d)/'source';root.mkdir();(root/'a.txt').write_text('same input')
            a,b=pathlib.Path(d)/'a.zip',pathlib.Path(d)/'b.zip'
            m.archive(a,root);m.archive(b,root)
            self.assertEqual(a.read_bytes(),b.read_bytes())
    def test_dangling_and_duplicate_references_fail(self):
        import sys;sys.path.insert(0,str(BASE));from validate import references
        dangling=E.fromstring(b'<roblox><Item referent="A"><Properties><Ref name="Part1">B</Ref></Properties></Item></roblox>')
        with self.assertRaisesRegex(ValueError,'unresolved'):references(dangling,'fixture')
        duplicate=E.fromstring(b'<roblox><Item referent="A"/><Item referent="A"/></roblox>')
        with self.assertRaisesRegex(ValueError,'duplicate'):references(duplicate,'fixture')

    def test_source_restores_ambiguous_brickcolor_xml_tag(self):
        self.load()
        from model_io import Source
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as directory:
            root=pathlib.Path(directory);binary=root/'source.rbxl';binary.write_bytes(binary_type_fixture())
            cache=root/'cache';cache.mkdir()
            (cache/(hashlib.sha256(binary.read_bytes()).hexdigest()+'.rbxlx')).write_bytes(
                b'<roblox version="4"><Item class="SpawnLocation" referent="A"><Properties><int name="TeamColor">194</int></Properties></Item>'
                b'<Item class="IntValue" referent="B"><Properties><int64 name="Value">4</int64></Properties></Item></roblox>')
            source=Source(binary,'must-not-run-rbxmk-for-cached-fixture',cache)
            prop=source.by[0].find('Properties/*[@name="TeamColor"]')
            self.assertEqual(prop.tag,'BrickColor')
            self.assertEqual(prop.text,'194')

    def test_binary_property_type_downgrade_fails(self):
        import sys;sys.path.insert(0,str(BASE));import validate
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as directory:
            root=pathlib.Path(directory);source=root/'source.rbxl';output=root/'output.rbxl'
            source.write_bytes(binary_type_fixture());output.write_bytes(binary_type_fixture(3,3))
            with self.assertRaisesRegex(ValueError,'SpawnLocation.TeamColor'):
                validate.binary_property_types(source,output)

    def test_binary_property_types_match_source(self):
        import sys;sys.path.insert(0,str(BASE));import validate
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as directory:
            root=pathlib.Path(directory);source=root/'source.rbxl';output=root/'output.rbxl'
            source.write_bytes(binary_type_fixture());output.write_bytes(binary_type_fixture())
            result=validate.binary_property_types(source,output)
            self.assertTrue(result['passed'])
            self.assertEqual(result['propertiesCompared'],2)

if __name__=='__main__':unittest.main()
