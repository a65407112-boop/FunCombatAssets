"""Public scripting references must preserve serialized original weld endpoints."""
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from lxml import etree as E

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from model_io import Source,package

class ModelReferences(unittest.TestCase):
    def test_serialized_weld_constraint_references_use_public_api_members(self):
        root=E.fromstring(b'<Item class="Model" referent="root"><Properties><string name="Name">TorsoRig</string></Properties><Item class="Part" referent="ref"><Properties><string name="Name">ref</string></Properties></Item><Item class="Part" referent="accent"><Properties><string name="Name">Accent</string></Properties></Item><Item class="WeldConstraint" referent="weld"><Properties><string name="Name">WeldConstraint</string><Ref name="Part0Internal">ref</Ref><Ref name="Part1Internal">accent</Ref></Properties></Item></Item>')
        items=list(root.iter('Item'));source=SimpleNamespace(by={i:e for i,e in enumerate(items)},reverse={e.get('referent'):i for i,e in enumerate(items)},name=Source.name)
        before=E.tostring(root);data=package(source,0);weld=data['nodes'][3]['properties']
        self.assertEqual(weld.get('Part0'),{'type':'Ref','value':1},'Serialized Part0Internal was not translated to scriptable Part0')
        self.assertEqual(weld.get('Part1'),{'type':'Ref','value':2},'Serialized Part1Internal was not translated to scriptable Part1')
        self.assertNotIn('Part0Internal',weld);self.assertNotIn('Part1Internal',weld)
        self.assertEqual(E.tostring(root),before)
        self.assertFalse(data['externalReferences'])

if __name__=='__main__':unittest.main()
