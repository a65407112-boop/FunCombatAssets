"""Run the actual player-avatar adapter against engine boundary fixtures."""
import argparse
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--luau', required=True)
args = p.parse_args()
code = (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += r'''
local calls=0
local Players={}
function Players:GetHumanoidDescriptionFromUserIdAsync()
    calls+=1
    error('A live native avatar must never be fetched and reapplied')
end
game.GetService=function(_,name) assert(name=='Players');return Players end
'''
code += '\nlocal Avatar=(function()\n' + (ROOT / 'Builder/templates/server/Avatar.lua').read_text() + '\nend)()\n'
code += r'''
local player=node('Player','Owner');player.Parent=true;player.UserId=123
local character=node('Model','Morph');character.Parent=true;player.Character=character
local humanoid=node('Humanoid','Humanoid');humanoid.Parent=character
local root=node('Part','HumanoidRootPart');root.Parent=character
local torso=node('Part','Torso');torso.Color='morph-color';torso.Parent=character
local head=node('MeshPart','Head');head.TextureID='native-texture';head.Parent=character
local face=node('FaceControls','FaceControls');face.Parent=head
local bone=node('Bone','FacialRig');bone.Parent=head
local native=node('LocalScript','Animate');native.Disabled=false;native.Parent=character
local package=node('CharacterMesh','PackageTorso');package.BodyPart=1;package.Parent=character
local headPackage=node('CharacterMesh','HeadPackage');headPackage.BodyPart=0;headPackage.Parent=character
Enum.BodyPart={Head=0,Torso=1}
local applyCount=0
function humanoid:ApplyDescriptionAsync() applyCount+=1;head:Destroy() end
local ready,why=Avatar.prepare(player,character,humanoid)
assert(ready and not why,'Native player preparation attempted an avatar fetch: '..tostring(why))
assert(calls==0 and applyCount==0,'Player morph was overwritten from its account avatar')
assert(character:FindFirstChild('Head')==head and face.Parent==head and bone.Parent==head,
    'Native dynamic head, FaceControls or bones were replaced')
assert(torso.Color=='morph-color' and not native.Disabled,'Morph color or native facial animation was overwritten')
assert(package.destroyed and not headPackage.destroyed,'Player did not become blocky or its head package was removed')
local again=Avatar.prepare(player,character,humanoid)
assert(again and calls==0 and applyCount==0,'Repeated combat initialization reapplied account appearance')
local replacement=node('Model','Replacement');replacement.Parent=true;player.Character=replacement
assert(not Avatar.prepare(player,character,humanoid),'A replaced character was accepted')
player.Character=character;player.Parent=nil
assert(not Avatar.prepare(player,character,humanoid),'A departed player was accepted')
player.Parent=true;humanoid.Health=0
assert(not Avatar.prepare(player,character,humanoid),'A dead avatar was accepted')
print('Native R6: morph/head/facial identity preserved; no appearance fetch or application; stale/dead avatars rejected')
'''
with tempfile.TemporaryDirectory(dir=ROOT.parent) as d:
    path=Path(d)/'native-r6.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
