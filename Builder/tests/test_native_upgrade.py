import sys
import unittest
from pathlib import Path
from lxml import etree as E

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import native_r6_upgrade as native


class NativeUpgradeTests(unittest.TestCase):
    def test_literal_data_keeps_reference_numbers_nested_tables_and_escaped_names(self):
        value=native.literal_table('return { ["name"]="Left Arm", ["nodes"]={{["id"]=12,["v"]=-0.5,["ok"]=true}},["line"]="a\\nb" }')
        self.assertEqual(value,{'name':'Left Arm','nodes':[{'id':12,'v':-0.5,'ok':True}],'line':'a\nb'})
        with self.assertRaises(ValueError):
            native.literal_table('return game:GetService("Players")')

    def test_native_settings_remove_only_custom_player_template_and_force_r6(self):
        tree=E.fromstring(b'<roblox><Item class="Workspace"><Properties/></Item><Item class="StarterPlayer"><Properties/><Item class="StarterCharacterScripts"><Properties/></Item><Item class="Model"><Properties><string name="Name">StarterCharacter</string></Properties></Item></Item><Item class="ServerStorage"><Properties/><Item class="Model"><Properties><string name="Name">NPC</string></Properties></Item></Item></roblox>')
        native.native_settings(tree)
        starter=tree.find('Item[@class="StarterPlayer"]')
        self.assertEqual(starter.findtext('Properties/token[@name="GameSettingsAvatar"]'),'0')
        self.assertEqual(starter.findtext('Properties/token[@name="EnableDynamicHeads"]'),'2')
        self.assertEqual(starter.findtext('Properties/bool[@name="LoadCharacterAppearance"]'),'true')
        self.assertEqual(starter.findtext('Properties/token[@name="AvatarJointUpgrade_SerializedRollout"]'),'1')
        self.assertEqual(tree.findtext('Item[@class="Workspace"]/Properties/token[@name="AvatarUnificationMode"]'),'1')
        self.assertIsNone(starter.find('Item[@class="Model"]'))
        self.assertIsNotNone(starter.find('Item[@class="StarterCharacterScripts"]'))
        self.assertIsNotNone(tree.find('Item[@class="ServerStorage"]/Item[@class="Model"]'))

    def test_saved_rig_uses_opaque_names_and_keeps_internal_joint_references(self):
        data={'root':1,'nodes':[
            {'id':1,'class':'Model','name':'Rig','properties':{'Name':{'type':'string','value':'Rig'},'PrimaryPart':{'type':'Ref','value':2}}},
            {'id':2,'class':'Part','name':'HumanoidRootPart','parent':1,'properties':{}},
            {'id':3,'class':'Part','name':'Torso','parent':1,'properties':{}},
            {'id':4,'class':'Motor6D','name':'RootJoint','parent':2,'properties':{'Part0':{'type':'Ref','value':2},'Part1':{'type':'Ref','value':3}}}]}
        root,aliases=native.saved_rig(data,'fixture')
        items=list(root.iter('Item'))
        self.assertEqual(len(items),4)
        for item in items:
            self.assertEqual(len(item.findall('Properties/*[@name="Name"]')),1)
            self.assertRegex(item.findtext('Properties/string[@name="Name"]'),r'^[0-9a-f]{12}$')
        ids={aliases[item.findtext('Properties/string[@name="Name"]')]:item.get('referent') for item in items}
        joint=next(x for x in items if x.get('class')=='Motor6D')
        self.assertEqual(joint.findtext('Properties/Ref[@name="Part0"]'),ids['HumanoidRootPart'])
        self.assertEqual(joint.findtext('Properties/Ref[@name="Part1"]'),ids['Torso'])


if __name__=='__main__':
    unittest.main()
