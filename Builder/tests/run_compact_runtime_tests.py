"""Actual runtime factories/codec at mocked Roblox API boundaries; no geometry test."""
import argparse, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);args=p.parse_args()
code=(ROOT/'Builder/tests/presentation_runtime.spec.luau').read_text()
code+='\nlocal Color3={new=function(...) return {...} end}\n'
code+='\nlocal RigFactory=(function()\n'+(ROOT/'Builder/templates/server/RigFactory.lua').read_text()+'\nend)()\n'
code+='\nlocal Codec=(function()\n'+(ROOT/'Builder/templates/server/WireCodec.lua').read_text()+'\nend)()\n'
code+='\nlocal WireFactory=(function()\n'+(ROOT/'client/wire.lua').read_text()+'\nend)()\n'
code+=r'''
local data={version=1,root=1,nodes={
 {id=1,class='Model',name='OriginalRig',properties={PrimaryPart={type='Ref',value=2}}},
 {id=2,class='Part',name='HumanoidRootPart',parent=1,properties={Anchored={type='bool',value=true}}},
 {id=3,class='Humanoid',name='Humanoid',parent=1,properties={WalkSpeed={type='number',value=16}}},
 {id=4,class='Motor6D',name='RootJoint',parent=2,properties={Part0={type='Ref',value=2},Part1={type='Ref',value=5}}},
 {id=5,class='Part',name='Torso',parent=1,properties={Color={type='Color3',value={0.1,0.2,0.3}}}}
}}
local rig=RigFactory.create(data)
assert(rig.PrimaryPart==rig:FindFirstChild('HumanoidRootPart'),'Original primary root was lost')
local root=rig.PrimaryPart;local torso=rig:FindFirstChild('Torso');local joint=root:FindFirstChild('RootJoint')
assert(joint.Part0==root and joint.Part1==torso and root.Anchored==true,'Original rig reference/property binding failed')
assert(torso.Color[1]==0.1 and rig:FindFirstChildOfClass('Humanoid').WalkSpeed==16,'Original palette/Humanoid fields changed')
assert(data.nodes[4].properties.Part0.value==2,'Rig constructor mutated source data')
local made={};local new=Instance.new
Instance.new=function(class,...)
 local v=new(class,...);made[#made+1]=v
 if class=='Motor6D' then
  local mt=getmetatable(v);local assign=mt.__newindex
  mt.__newindex=function(self,key,value) if key=='Part0' then error('fixture invalid joint') end;assign(self,key,value) end
 end
 return v
end
local ok,why=pcall(RigFactory.create,data);Instance.new=new
assert(not ok and tostring(why):find('Part0'),'Critical connection failure was swallowed')
for _,v in ipairs(made) do assert(v.destroyed,'Partial failed rig leaked') end
local aliases={['bat/swing1']='wire_anim',['weapons/Bat']='wire_weapon',Crossroads='wire_map'}
local reverse={wire_anim='bat/swing1',wire_weapon='weapons/Bat',wire_map='Crossroads'}
local state={character=rig,animation={key='bat/swing1'},candidates={{name='Crossroads'}},votes={Crossroads=2},weapon='weapons/Bat'}
local encoded=Codec.transform(state,aliases)
assert(encoded~=state and state.animation.key=='bat/swing1','Encoding mutated server state')
assert(encoded.character==rig and encoded.animation.key=='wire_anim','Encoding changed Instance identity or left readable resource key')
assert(encoded.votes.wire_map==2 and encoded.candidates[1].name=='wire_map','Map dictionary/value aliases differ')
local decoded=Codec.transform(encoded,reverse)
assert(decoded.votes.Crossroads==2 and decoded.weapon=='weapons/Bat' and decoded.character==rig,'Codec roundtrip failed')
local cyclic={};cyclic.self=cyclic
assert(Codec.transform(cyclic,aliases).self~=nil,'Cycle handling failed')
local tooBig={};for i=1,300 do tooBig[i]='invalid' end
assert(not pcall(Codec.decodeAction,tooBig,aliases),'Hostile action payload was decoded without a work limit')
local wire=WireFactory({protocol={presentationIds={['bat/swing1']='wire_anim'}},identifiers={mapNames={Crossroads='wire_map'}}})
local shown=wire:decode({animation={key='wire_anim'},votes={wire_map=2},text='Switching to Map: wire_map In 5 Seconds',character=rig})
assert(shown.animation.key=='bat/swing1' and shown.votes.Crossroads==2 and shown.character==rig,'Actual client wire module disagrees with server snapshot encoding')
assert(shown.text=='Switching to Map: Crossroads In 5 Seconds','Map notice exposed its internal name')
assert(wire:encode('Crossroads')=='wire_map' and wire:encode('bat/swing1')=='wire_anim','Actual client action binding differs')
print('Compact runtime: original rig construction, failed-joint cleanup and wire snapshot/Instance roundtrip passed')
'''
with tempfile.TemporaryDirectory(dir=ROOT.parent) as d:
 f=Path(d)/'compact.luau';f.write_text(code)
 subprocess.run([str(Path(args.luau).resolve()),str(f)],check=True)
