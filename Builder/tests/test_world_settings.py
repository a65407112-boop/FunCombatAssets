import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from lxml import etree as E

ROOT=Path(__file__).resolve().parents[2]

class WorldSettingsTests(unittest.TestCase):
    def builder(self):
        spec=importlib.util.spec_from_file_location('settings_builder',ROOT/'Builder/build.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
    def source(self,enabled):
        xml=E.fromstring(('<Item class="Workspace" referent="W"><Properties><string name="Name">Workspace</string></Properties>'
            '<Item class="Configuration" referent="C"><Properties><string name="Name">Configuration</string></Properties>'
            '<Item class="BoolValue" referent="B"><Properties><string name="Name">AllowDummys</string><bool name="Value">'+
            ('true' if enabled else 'false')+'</bool><BinaryString name="AttributesSerialize">opaque-source</BinaryString></Properties></Item></Item></Item>').encode())
        tree=E.Element('roblox');tree.append(xml)
        # In the inspected source, Workspace is node 0; node 17 is a map.
        # Recover settings from the actual service rather than the map index.
        map_model=E.SubElement(xml,'Item',{'class':'Model','referent':'M'})
        properties=E.SubElement(map_model,'Properties')
        E.SubElement(properties,'string',{'name':'Name'}).text='Crossroads'
        return SimpleNamespace(tree=tree,by={0:xml,17:map_model}),xml
    def test_original_settings_are_copied_without_duplicate_referents_or_source_edits(self):
        m=self.builder();self.assertTrue(callable(getattr(m,'add_world_settings',None)),'Original configuration backup exporter is missing')
        for enabled in (True,False):
            with self.subTest(enabled=enabled):
                source,xml=self.source(enabled);before=E.tostring(xml);storage=E.Element('Item',{'class':'Folder','referent':'S'})
                m.add_world_settings(source,storage)
                backup=storage.find('Item');flag=backup.find('Item')
                self.assertEqual(backup.get('class'),'Configuration')
                self.assertEqual(backup.findtext('Properties/string[@name="Name"]'),'WorldSettings')
                self.assertEqual(flag.findtext('Properties/bool[@name="Value"]'),'true' if enabled else 'false')
                self.assertEqual(flag.findtext('Properties/BinaryString[@name="AttributesSerialize"]'),'opaque-source')
                self.assertEqual(E.tostring(xml),before)
                self.assertFalse({x.get('referent') for x in xml.iter('Item')} & {x.get('referent') for x in backup.iter('Item')})
                second=E.Element('Item');m.add_world_settings(source,second)
                self.assertEqual(E.tostring(storage.find('Item')),E.tostring(second.find('Item')))
    def test_missing_original_flag_is_rejected_without_a_fabricated_default(self):
        m=self.builder();self.assertTrue(callable(getattr(m,'add_world_settings',None)),'Original configuration backup exporter is missing')
        source,xml=self.source(True);xml.find('Item').remove(xml.find('Item/Item'))
        with self.assertRaisesRegex(ValueError,'AllowDummys'):m.add_world_settings(source,E.Element('Item'))
