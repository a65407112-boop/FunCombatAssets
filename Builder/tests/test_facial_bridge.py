"""Check the native facial marker without reading model geometry."""
import importlib.util
from pathlib import Path
import unittest
from lxml import etree as E

ROOT=Path(__file__).resolve().parents[2]

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

class FacialBridgeTests(unittest.TestCase):
    def fixture(self):
        b=module('facial_builder',ROOT/'Builder/build.py')
        tree=E.Element('roblox')
        starter=b.instance('StarterPlayer','StarterPlayer');tree.append(starter)
        character=b.instance('Model','StarterCharacter');starter.append(character)
        storage=b.instance('ServerStorage','ServerStorage');tree.append(storage)
        data=b.instance('Folder','FunCombatData');storage.append(data)
        dummy=b.instance('Model','DummyRig');data.append(dummy)
        return b,tree,character,dummy
    def test_two_engine_named_markers_have_unique_referents_and_no_body_animation_code(self):
        b,tree,character,dummy=self.fixture()
        self.assertTrue(callable(getattr(b,'add_facial_marker',None)),'Native facial marker builder is missing')
        for rig in (character,dummy):b.add_facial_marker(rig)
        refs=[item.get('referent') for item in tree.iter('Item')]
        self.assertEqual(len(refs),len(set(refs)))
        v=module('facial_validate',ROOT/'Builder/validate.py')
        self.assertEqual(v.facial_markers(tree),2)
        for rig in (character,dummy):
            animate=rig.find('Item');self.assertEqual(animate.get('class'),'LocalScript')
            self.assertEqual(animate.findtext('Properties/string[@name="Name"]'),'Animate')
            self.assertEqual(animate.findtext('Properties/bool[@name="Disabled"]'),'false')
            self.assertTrue(animate.findtext('Properties/ProtectedString[@name="Source"]').strip().startswith('--'))
    def test_validator_rejects_unexpected_clients_and_executable_marker_source(self):
        b,tree,character,dummy=self.fixture()
        self.assertTrue(callable(getattr(b,'add_facial_marker',None)),'Native facial marker builder is missing')
        for rig in (character,dummy):b.add_facial_marker(rig)
        v=module('facial_validate',ROOT/'Builder/validate.py')
        b.set_property(character.find('Item'),'Source','ProtectedString','print("unexpected body client")')
        with self.assertRaisesRegex(ValueError,'facial'):v.facial_markers(tree)
        b,tree,character,dummy=self.fixture()
        for rig in (character,dummy):b.add_facial_marker(rig)
        tree.append(b.instance('LocalScript','Unexpected'))
        with self.assertRaisesRegex(ValueError,'facial'):v.facial_markers(tree)
    def test_marker_export_is_deterministic_and_does_not_mutate_the_original_rig(self):
        import copy
        b,_,character,_=self.fixture()
        self.assertTrue(callable(getattr(b,'add_facial_marker',None)),'Native facial marker builder is missing')
        source=E.tostring(character);one=copy.deepcopy(character);two=copy.deepcopy(character)
        b.add_facial_marker(one);b.add_facial_marker(two)
        self.assertEqual(E.tostring(one),E.tostring(two))
        self.assertEqual(E.tostring(character),source)
    def test_binary_roundtrip_source_string_keeps_the_exact_noop_contract(self):
        b,tree,character,dummy=self.fixture()
        for rig in (character,dummy):
            b.add_facial_marker(rig)
            # ProtectedString and string both encode as native binary type1.
            rig.find('Item/Properties/ProtectedString[@name="Source"]').tag='string'
        v=module('facial_validate',ROOT/'Builder/validate.py')
        self.assertEqual(v.facial_markers(tree),2)
        character.find('Item/Properties/string[@name="Source"]').text='print("body script")'
        with self.assertRaisesRegex(ValueError,'facial'):v.facial_markers(tree)
