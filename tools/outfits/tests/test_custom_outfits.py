import json
import sys
import tempfile
import unittest
from pathlib import Path
from lxml import etree as E

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from custom_outfits import export_outfit


class CustomOutfits(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / 'GitHub'
        self.repo.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def source(self, extra=''):
        path = self.root / 'pp.rbxmx'
        path.write_text('''<roblox version="4"><Item class="Model" referent="m"><Properties><string name="Name">pp</string></Properties>
<Item class="Accessory" referent="a"><Properties><string name="Name">Backpack</string></Properties>
<Item class="Part" referent="p"><Properties><string name="Name">Handle</string></Properties>
<Item class="Attachment" referent="att"><Properties><string name="Name">WaistBackAttachment</string></Properties></Item>
</Item></Item>''' + extra + '</Item></roblox>')
        return path

    def test_own_costume_names_and_graph_are_preserved(self):
        source = self.source()
        before = source.read_bytes()
        entry = export_outfit(source, 'pp', self.repo)
        data = json.loads((self.repo / entry['path']).read_text())
        self.assertEqual([n['name'] for n in data['nodes']], ['pp','Backpack','Handle','WaistBackAttachment'])
        self.assertEqual(data['nodes'][1]['parent'], data['root'])
        self.assertFalse(data['externalReferences'])
        self.assertEqual(source.read_bytes(), before)
        config = json.loads((self.repo / 'config/outfits.json').read_text())
        self.assertEqual(config['packages']['pp'], entry)
        self.assertEqual(config['byGender']['Male'], 'pp')

    def test_script_and_animation_are_rejected_before_writing(self):
        for cls in ('Script','LocalScript','ModuleScript','KeyframeSequence','Animation','RemoteEvent'):
            with self.subTest(cls=cls):
                source=self.source('<Item class="'+cls+'" referent="x"><Properties><string name="Name">extra</string></Properties></Item>')
                with self.assertRaisesRegex(ValueError, 'not a costume class'):
                    export_outfit(source,'pp',self.repo)
                self.assertFalse((self.repo/'config/outfits.json').exists())

    def test_external_reference_is_not_silently_discarded(self):
        source=self.source('<Item class="Weld" referent="w"><Properties><string name="Name">Weld</string><Ref name="Part0">outside</Ref></Properties></Item>')
        with self.assertRaisesRegex(ValueError,'reference'):
            export_outfit(source,'pp',self.repo)

    def test_name_or_missing_handle_is_reported(self):
        source=self.source()
        with self.assertRaisesRegex(ValueError,'root name'):
            export_outfit(source,'boba',self.repo)
        source.write_text(source.read_text().replace('>Handle<','>WrongPart<'))
        with self.assertRaisesRegex(ValueError,'Handle'):
            export_outfit(source,'pp',self.repo)

    def test_shared_strings_are_preserved_in_companion(self):
        source=self.source()
        data=source.read_text().replace('<string name="Name">Handle</string>',
            '<string name="Name">Handle</string><SharedString name="PhysicsData">XUFAKrxLKna5cZ2REBfFkg==</SharedString>')
        data=data.replace('</roblox>', '<SharedStrings><SharedString md5="XUFAKrxLKna5cZ2REBfFkg==">aGVsbG8=</SharedString><SharedString md5="unused">dW51c2Vk</SharedString></SharedStrings></roblox>')
        source.write_text(data)
        entry=export_outfit(source,'pp',self.repo)
        saved=E.parse(str(self.repo/entry['modelPath']))
        dictionary={p.get('md5'):p.text for p in saved.findall('SharedStrings/SharedString')}
        self.assertEqual(dictionary,{'XUFAKrxLKna5cZ2REBfFkg==':'aGVsbG8='})
        self.assertTrue(all(p.text in dictionary for p in saved.findall('.//Properties/SharedString')))
        self.assertEqual(source.read_text(),data)

    def test_missing_shared_string_rejected_before_writing(self):
        source=self.source()
        source.write_text(source.read_text().replace('<string name="Name">Handle</string>',
            '<string name="Name">Handle</string><SharedString name="PhysicsData">missing</SharedString>'))
        with self.assertRaisesRegex(ValueError,'SharedString'):
            export_outfit(source,'pp',self.repo)
        self.assertFalse((self.repo/'assets').exists())

    def test_source_cannot_be_its_own_output(self):
        source=self.source()
        target=self.repo/'assets/outfits/pp.rbxmx';target.parent.mkdir(parents=True)
        target.write_bytes(source.read_bytes());before=target.read_bytes()
        with self.assertRaisesRegex(ValueError,'source'):
            export_outfit(target,'pp',self.repo)
        self.assertEqual(target.read_bytes(),before)

    def test_github_batch_updates_both_slots_without_touching_source_or_metadata(self):
        from custom_outfits import import_directory
        inputs=self.repo/'imports/outfits';inputs.mkdir(parents=True)
        raw=self.source().read_text()
        (inputs/'pp.rbxmx').write_text(raw)
        (inputs/'boba.rbxmx').write_text(raw.replace('>pp<','>boba<'))
        (self.repo/'manifest.json').write_text(json.dumps({'modules':['existing'], 'custom':'keep', 'files':{}}))
        (self.repo/'.git').mkdir();(self.repo/'.git/HEAD').write_text('ref: refs/heads/main')
        config={'version':1,'byGender':{'Male':'pp','Female':'boba','Fembxy':'pp'},'packages':{}}
        (self.repo/'config').mkdir();(self.repo/'config/outfits.json').write_text(json.dumps(config))
        result=import_directory(self.repo)
        self.assertEqual(result,['pp','boba'])
        self.assertEqual((inputs/'pp.rbxmx').read_text(),raw)
        updated=json.loads((self.repo/'config/outfits.json').read_text())
        self.assertEqual(updated['byGender'],config['byGender'])
        self.assertEqual(set(updated['packages']),{'pp','boba'})
        manifest=json.loads((self.repo/'manifest.json').read_text())
        self.assertEqual(manifest['modules'],['existing'])
        self.assertEqual(manifest['custom'],'keep')
        self.assertNotIn('.git/HEAD',manifest['files'])
        self.assertIn('assets/outfits/pp.json',manifest['files'])
        import zlib
        self.assertEqual(manifest['files']['assets/outfits/pp.json'].get('adler32'),
                         zlib.adler32((self.repo/'assets/outfits/pp.json').read_bytes())&0xffffffff)

    def test_invalid_second_model_leaves_live_packages_unchanged(self):
        from custom_outfits import import_directory
        inputs=self.repo/'imports/outfits';inputs.mkdir(parents=True)
        raw=self.source().read_text()
        (inputs/'pp.rbxmx').write_text(raw)
        (inputs/'boba.rbxmx').write_text(raw)
        before={p.relative_to(self.repo):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        with self.assertRaisesRegex(ValueError,'root name'):
            import_directory(self.repo)
        after={p.relative_to(self.repo):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        self.assertEqual(before,after)

    def test_new_model_names_are_preserved_in_both_slots(self):
        for name,slot in [('LowerRig','pp'),('TorsoRig','boba'),('Boba','boba')]:
            with self.subTest(name=name):
                raw=self.source().read_text().replace('>pp<','>'+name+'<')
                source=self.root/(name+'.rbxmx');source.write_text(raw)
                entry=export_outfit(source,name,self.repo)
                data=json.loads((self.repo/entry['path']).read_text())
                self.assertEqual(data['nodes'][0]['name'],name)
                self.assertEqual(data['nodes'][1]['name'],'Backpack')
                self.assertEqual(source.read_text(),raw)
                config=json.loads((self.repo/'config/outfits.json').read_text())
                self.assertEqual(config['packages'][slot],entry)

    def test_github_accepts_new_model_filenames(self):
        from custom_outfits import import_directory
        inputs=self.repo/'imports/outfits';inputs.mkdir(parents=True)
        raw=self.source().read_text()
        for name in ('LowerRig','TorsoRig'):
            (inputs/(name+'.rbxmx')).write_text(raw.replace('>pp<','>'+name+'<'))
        self.assertEqual(import_directory(self.repo),['pp','boba'])
        for name,slot in [('LowerRig','pp'),('TorsoRig','boba')]:
            data=json.loads((self.repo/'assets/outfits'/(slot+'.json')).read_text())
            self.assertEqual(data['nodes'][0]['name'],name)
        config=json.loads((self.repo/'config/outfits.json').read_text())
        self.assertEqual(config['byGender'],{'Male':'pp','Female':'boba','Fembxy':'boba'})

    def test_two_names_for_same_slot_do_not_overwrite_each_other(self):
        from custom_outfits import import_directory
        inputs=self.repo/'imports/outfits';inputs.mkdir(parents=True)
        raw=self.source().read_text()
        (inputs/'pp.rbxmx').write_text(raw)
        (inputs/'LowerRig.rbxmx').write_text(raw.replace('>pp<','>LowerRig<'))
        before={p.relative_to(self.repo):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        with self.assertRaisesRegex(ValueError,'one source'):
            import_directory(self.repo)
        after={p.relative_to(self.repo):p.read_bytes() for p in self.repo.rglob('*') if p.is_file()}
        self.assertEqual(before,after)

    def test_pp_and_capital_boba_keep_names_and_gender_mapping(self):
        from custom_outfits import import_directory
        inputs=self.repo/'imports/outfits';inputs.mkdir(parents=True)
        raw=self.source().read_text()
        (inputs/'pp.rbxmx').write_text(raw)
        (inputs/'Boba.rbxmx').write_text(raw.replace('>pp<','>Boba<'))
        self.assertEqual(import_directory(self.repo),['pp','boba'])
        data=json.loads((self.repo/'assets/outfits/boba.json').read_text())
        self.assertEqual(data['nodes'][0]['name'],'Boba')
        config=json.loads((self.repo/'config/outfits.json').read_text())
        self.assertEqual(config['byGender']['Female'],'boba')
        self.assertEqual(config['byGender']['Fembxy'],'boba')
        (inputs/'boba.rbxmx').write_text(raw.replace('>pp<','>boba<'))
        before=(self.repo/'assets/outfits/boba.json').read_bytes()
        with self.assertRaisesRegex(ValueError,'one source'):
            import_directory(self.repo)
        self.assertEqual((self.repo/'assets/outfits/boba.json').read_bytes(),before)


if __name__ == '__main__':
    unittest.main()
