import hashlib, importlib.util, json, pathlib, struct, tempfile, unittest
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

    def test_numeric_owner_settings_preserve_large_roblox_user_id(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as directory:
            root=pathlib.Path(directory);(root/'config').mkdir()
            (root/'config/admin.json').write_text(json.dumps({'version':1,'ownerUserId':11556197791}))
            self.assertTrue(callable(getattr(m,'read_admin_settings',None)), 'Validated server owner configuration is missing')
            self.assertEqual(m.read_admin_settings(root)['ownerUserId'],11556197791)

    def test_invalid_owner_settings_are_rejected_before_compilation(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as directory:
            root=pathlib.Path(directory);(root/'config').mkdir()
            self.assertTrue(callable(getattr(m,'read_admin_settings',None)), 'Validated server owner configuration is missing')
            for invalid in [None,True,'11556197791',0,-1,1.5,9007199254740992]:
                with self.subTest(owner=invalid):
                    (root/'config/admin.json').write_text(json.dumps({'version':1,'ownerUserId':invalid}))
                    with self.assertRaisesRegex(ValueError,'ownerUserId'):m.read_admin_settings(root)
            (root/'config/admin.json').write_text(json.dumps({'version':2,'ownerUserId':11556197791}))
            with self.assertRaisesRegex(ValueError,'version'):m.read_admin_settings(root)

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

    def test_native_csg_dependency_preserves_original_data_without_children(self):
        from types import SimpleNamespace
        m=self.load()
        source=E.fromstring(b'<Item class="UnionOperation" referent="Original"><Properties><string name="Name">OriginalPart</string><BinaryString name="OpaqueData">b3JpZ2luYWw=</BinaryString></Properties><Item class="Attachment" referent="OriginalChild"><Properties><string name="Name">Attachment</string></Properties></Item></Item>')
        before=E.tostring(source);replicated=E.fromstring(b'<Item class="ReplicatedStorage" referent="Storage"><Properties/></Item>')
        self.assertTrue(callable(getattr(m,'add_native_csg',None)), 'Builder lacks native original CSG dependency migration')
        m.add_native_csg(SimpleNamespace(by={12:source}),replicated,{'folder':'EncodedDependency','nodes':{'12':'EncodedOriginalPart'}})
        native=replicated.find('Item/Item')
        self.assertEqual(native.get('class'),'UnionOperation')
        self.assertEqual(native.findtext('Properties/BinaryString[@name="OpaqueData"]'),'b3JpZ2luYWw=')
        self.assertEqual(native.findtext('Properties/string[@name="Name"]'),'EncodedOriginalPart')
        self.assertEqual(native.findall('Item'),[])
        self.assertNotEqual(native.get('referent'),'Original')
        self.assertEqual(E.tostring(source),before)

    def test_kohl_native_settings_and_commands_survive_migration(self):
        from types import SimpleNamespace
        m=self.load()
        original=E.fromstring(b'<Item class="Script" referent="Credit"><Properties><string name="Name">Credit</string><ProtectedString name="Source">require(1868400649)</ProtectedString></Properties><Item class="ModuleScript" referent="Settings"><Properties><string name="Name">Settings</string><ProtectedString name="Source">return {Prefix=\":\",FreeAdmin=false}</ProtectedString></Properties></Item><Item class="ModuleScript" referent="Custom"><Properties><string name="Name">Custom Commands</string><ProtectedString name="Source">return {{{\"test\"},{\"Original command\"},6,{},function() end}}</ProtectedString></Properties></Item></Item>')
        before=E.tostring(original);service=E.fromstring(b'<Item class="ServerScriptService" referent="Server"><Properties/></Item>')
        self.assertTrue(callable(getattr(m,'add_kohl_admin',None)),'Original Kohl settings are not migrated')
        native=m.add_kohl_admin(SimpleNamespace(by={6657:original}),service)
        self.assertEqual(native.findtext('Properties/string[@name="Name"]'),"Kohl's Admin Infinite")
        self.assertEqual(native.findtext('Properties/bool[@name="Disabled"]'),'true')
        children={m.Source.name(e):e for e in native.findall('Item')}
        self.assertEqual(children['Settings'].findtext('Properties/ProtectedString[@name="Source"]'),'return {Prefix=":",FreeAdmin=false}')
        body=children['Custom Commands'].findtext('Properties/ProtectedString[@name="Source"]')
        self.assertIn('"test"',body);self.assertIn('FunCombatDummy',body);self.assertIn('.commands(bridge)',body)
        self.assertEqual(E.tostring(original),before)

if __name__=='__main__':unittest.main()
