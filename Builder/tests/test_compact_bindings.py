import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from compact import rewrite_bindings, semantic

class CompactBindingsTests(unittest.TestCase):
    def test_nested_object_lookup_and_stat_references_keep_one_binding(self):
        code='local C=require(script.Parent.Config);local a=object:FindFirstChild(object.Name=="TeleportPart1" and "TeleportPart2" or "TeleportPart1");player.leaderstats.Kills.Value+=1;game:GetService("Players")'
        names={'Config':'m1','TeleportPart1':'p1','TeleportPart2':'p2','Kills':'s1','Players':'must-not-change'}
        rewritten=rewrite_bindings(code,names,{},dots={'Config','Kills'})
        expected='local C=require(script.Parent["m1"]);local a=object:FindFirstChild(object.Name=="p1" and "p2" or "p1");player.leaderstats["s1"].Value+=1;game:GetService("Players")'
        self.assertEqual(semantic(rewritten),semantic(expected))

    def test_client_resource_names_stay_original_while_server_attribute_binding_matches(self):
        code='local a=model:FindFirstChild("OriginalWeapon");local b=character:GetAttribute("FunCombatMoodClipId");ctx.catalog.packages["weapons/Sword"]'
        rewritten=rewrite_bindings(code,{'OriginalWeapon':'w1'},{'FunCombatMoodClipId':'a1'},client=True)
        self.assertEqual(semantic(rewritten),semantic(code.replace('"FunCombatMoodClipId"','"a1"')))

    def test_client_without_server_attributes_keeps_decimal_literals_and_license_comments(self):
        source='-- Copyright original author\nlocal value=.75;return value'
        self.assertEqual(rewrite_bindings(source,{}, {},client=True),source)

if __name__=='__main__':unittest.main()
