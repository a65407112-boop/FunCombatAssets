"""World export must not alter the geometry that keeps server physics shared."""
import sys
import unittest
import os
import shutil
import tempfile
from pathlib import Path
from lxml import etree as E

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import client_world_upgrade as world


class ClientWorldExportTests(unittest.TestCase):
    def test_native_encoder_keeps_an_omitted_model_reference_null(self):
        rbxmk=os.environ.get('FUNCOMBAT_RBXMK') or shutil.which('rbxmk')
        if not rbxmk:self.skipTest('Set FUNCOMBAT_RBXMK to run the real native encoder check')
        tree=E.fromstring(b'<roblox version="4"><Item class="Workspace"><Properties><string name="Name">Workspace</string></Properties><Item class="Model"><Properties><Ref name="PrimaryPart">null</Ref></Properties></Item><Item class="Model"><Properties/></Item></Item><Item class="ServerScriptService"><Properties><string name="Name">ServerScriptService</string></Properties></Item></roblox>')
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);binary=root/'place.rbxl'
            world.encode(tree,root/'place.rbxlx',binary,rbxmk,'rbxl')
            self.assertEqual(world.validate_saved_reference_types(binary)['referencesChecked'],2)
            from model_io import Source
            decoded=Source(binary,rbxmk,root/'decoded')
            models=decoded.tree.findall('.//Item[@class="Model"]')
            self.assertEqual(len(models),2)
            self.assertTrue(all(m.findtext('Properties/Ref[@name="PrimaryPart"]')=='null' for m in models))
            ids=[item.findtext('Properties/UniqueId[@name="UniqueId"]') for item in decoded.tree.iter('Item')]
            self.assertEqual(len(ids),4)
            self.assertTrue(all(value and value!='0'*32 for value in ids))
            self.assertEqual(len(set(ids)),4)

    def test_hiding_presentation_preserves_collision_and_world_transform(self):
        root = E.fromstring(b'''<Item class="Model"><Properties/>
        <Item class="Part"><Properties><bool name="CanCollide">true</bool>
        <bool name="Anchored">true</bool><float name="Transparency">0.2</float>
        <CoordinateFrame name="CFrame"><X>11</X><Y>22</Y><Z>33</Z></CoordinateFrame>
        <Vector3 name="Size"><X>4</X><Y>5</Y><Z>6</Z></Vector3></Properties>
        <Item class="Decal"><Properties><float name="Transparency">0</float></Properties></Item>
        <Item class="SurfaceGui"><Properties><bool name="Enabled">true</bool></Properties></Item>
        <Item class="ProximityPrompt"><Properties><bool name="Enabled">true</bool></Properties></Item>
        </Item></Item>''')
        before = E.tostring(root.find('.//CoordinateFrame'))
        world.hide_presentation(root)
        part = root.find('Item')
        self.assertEqual(part.findtext('Properties/float[@name="Transparency"]'), '1')
        self.assertEqual(part.findtext('Properties/bool[@name="CanCollide"]'), 'true')
        self.assertEqual(part.findtext('Properties/bool[@name="Anchored"]'), 'true')
        self.assertEqual(E.tostring(part.find('Properties/CoordinateFrame')), before)
        self.assertEqual(part.findtext('Properties/Vector3/Y'), '5')
        self.assertEqual(part.findtext('Item[@class="Decal"]/Properties/float[@name="Transparency"]'), '1')
        self.assertEqual(part.findtext('Item[@class="SurfaceGui"]/Properties/bool[@name="Enabled"]'), 'false')
        self.assertEqual(part.findtext('Item[@class="ProximityPrompt"]/Properties/bool[@name="Enabled"]'), 'true')

    def test_waiting_room_has_closed_walls_roof_and_supported_neutral_spawn(self):
        room = world.waiting_room()
        self.assertEqual(room.findtext('Properties/Ref[@name="PrimaryPart"]'),'null',
                         'A new model must not default its PrimaryPart reference to instance zero')
        parts = [p for p in room.iter('Item') if p.get('class') in {'Part', 'SpawnLocation'}]
        solids = [p for p in parts if p.findtext('Properties/bool[@name="CanCollide"]') == 'true']
        self.assertEqual(len(solids), 6)
        spawn = next(p for p in parts if p.get('class') == 'SpawnLocation')
        self.assertEqual(spawn.findtext('Properties/bool[@name="Enabled"]'), 'true')
        self.assertEqual(spawn.findtext('Properties/bool[@name="Neutral"]'), 'true')
        self.assertEqual(spawn.findtext('Properties/CoordinateFrame/Y'), '1002')
        for item in room.iter('Item'):
            self.assertRegex(item.findtext('Properties/string[@name="Name"]'), '^[0-9a-f]{12}$')
        for part in solids:
            self.assertEqual(part.findtext('Properties/bool[@name="Anchored"]'), 'true')
            self.assertIsNotNone(part.find('Properties/Vector3[@name="size"]'),
                'New parts must use the existing native size field, not add a parallel Size property')
            self.assertEqual(part.findtext('Properties/token[@name="shape"]'), '1',
                'Room walls must serialize as blocks, not the zero-valued ball shape')

    def test_export_strips_executables_and_remaps_external_references_to_null(self):
        root = E.fromstring(b'''<Item class="Model" referent="root"><Properties>
        <string name="Name">map</string><Ref name="PrimaryPart">part</Ref></Properties>
        <Item class="Part" referent="part"><Properties><string name="Name">floor</string>
        <Ref name="Outside">other-map</Ref></Properties></Item>
        <Item class="Script" referent="script"><Properties><string name="Name">bad</string></Properties></Item>
        </Item>''')
        copy = world.presentation_copy(root)
        self.assertEqual([x.get('class') for x in copy.iter('Item')], ['Model', 'Part'])
        self.assertEqual(copy.findtext('Properties/Ref[@name="PrimaryPart"]'), 'part')
        self.assertEqual(copy.findtext('Item/Properties/Ref[@name="Outside"]'), 'null')
        self.assertEqual(len(root.findall('Item')), 2)


if __name__ == '__main__':
    unittest.main()
