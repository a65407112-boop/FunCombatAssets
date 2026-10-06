"""Real carry/drop/removal code with engine API doubles, not a physics test."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += r'''
Enum.HumanoidStateType={Physics=1,GettingUp=2}
local Players={GetPlayers=function() return {} end}
game.GetService=function(_,name) if name=='Players' then return Players else return {} end end
local script={Parent={Policy='Policy',Ragdoll='Ragdoll',PairSystem='PairSystem'}}
local modules={}
local function require(name) if name=='PairSystem' then return function() end end;return modules[name] or {} end
'''
for key, name in [('Policy', 'Policy.lua'), ('Ragdoll', 'Ragdoll.lua'), ('Combat', 'CombatServer.lua')]:
    code += '\nmodules[' + repr(key) + ']=(function()\n' + (ROOT / 'Builder/templates/server' / name).read_text() + '\nend)()\n'
code += r'''
local positions={};positions.__index=positions
local function position(x) return setmetatable({X=x,Magnitude=math.abs(x)},positions) end
function positions.__sub(a,b) return position(a.X-b.X) end
local function fixture(distance)
    now=100
    local templates=node('Folder','Templates');local weld=node('Weld','CarryWeld');weld.C0=frame(0,1,-1);weld.C1=frame();weld.Parent=templates
    local C=modules.Combat
    local combat=setmetatable({records={},players={},dummyOwners={},holds={},templates=templates},C)
    function combat:emit() end
    local function actor(name,x)
        local player=node('Player',name);player.Parent=true;player.UserId=x+1;player.leaderstats={Kills={Value=0},Killstreak={Value=0},Completions={Value=0}}
        local c,_,_,_=character();c.Name=name
        local root=node('Part','HumanoidRootPart');root.Parent=c;root.Anchored=false;root.Position=position(x);root.CFrame=frame(x,0,0)
        function root:SetNetworkOwner(owner) self.lastOwner=owner end
        local hum=node('Humanoid','Humanoid');hum.Parent=c;hum.MaxHealth=100;hum.PlatformStand=false;hum.EvaluateStateMachine=true
        function hum:ChangeState(state) self.state=state end
        local torso=c:FindFirstChild('Torso');torso.Position=position(x);torso.CanCollide=true;torso.Massless=false
        local r={character=c,player=player,root=root,torso=torso,humanoid=hum,revision=0,animationRevision=0,connections={},
            attacks={},prompts={},downed=false,ragdolled=false,stunUntil=0,walkSpeed=16,jumpPower=50,jumpHeight=7.2,
            getUpCount=0,weapon='Bat',funMeter=0}
        combat.records[c]=r;combat.players[player]=r;return r
    end
    local a,v=actor('Carrier',0),actor('Victim',distance or 2)
    v.downed=true;combat:setRagdoll(v,true)
    return combat,a,v
end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Carry: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
check('carrier owns the welded assembly and retains walking controls',function()
    local combat,a,v=fixture();combat:carry(a,v)
    assert(a.carrying==v and v.carriedBy==a,'Valid original carry was rejected')
    assert(a.root.lastOwner==a.player,'Carry removed physics control from the walking player')
    assert(not a.root.Anchored and not v.root.Anchored and a.humanoid.WalkSpeed==16 and a.humanoid.AutoRotate,
        'Carry disabled carrier movement')
    assert(v.humanoid.PlatformStand and v.humanoid.EvaluateStateMachine==false,'Victim controller still pushes the carrier assembly')
    assert(v.humanoid.WalkSpeed==0 and a.carryWeld.Part0==a.torso and a.carryWeld.Part1==v.root)
    assert(not v.torso.CanCollide and v.torso.Massless,'Victim still collides with the carrier')
end)
check('carried victim cannot apply standing forces to the shared assembly',function()
    local combat,a,v=fixture();combat:carry(a,v)
    assert(v.humanoid.PlatformStand and v.humanoid.EvaluateStateMachine==false,'Victim controller still pushes the carrier assembly')
end)
check('drop restores victim state machine, collisions and separate ownership',function()
    local combat,a,v=fixture();combat:carry(a,v);combat:drop(a)
    assert(not a.carrying and not v.carriedBy and not a.carryWeld,'Drop retained the welded carry state')
    assert(v.humanoid.EvaluateStateMachine==true,'Drop left victim state evaluation disabled')
    assert(v.torso.CanCollide and not v.torso.Massless,'Drop retained cosmetic-only victim physics')
    assert(a.root.lastOwner==a.player and v.root.lastOwner==nil,'Drop assigned ownership to the wrong player')
    assert(v.ragdolled and v.humanoid.PlatformStand,'The downed victim did not return to ragdoll')
    combat:setRagdoll(v,false);assert(not v.humanoid.PlatformStand,'Get-up retained the carry PlatformStand flag')
end)
check('carrier removal releases victim controller and welded state',function()
    local combat,a,v=fixture();combat:carry(a,v);combat:remove(a.character)
    assert(not v.carriedBy and v.humanoid.EvaluateStateMachine==true,'Carrier respawn left the victim locked')
    assert(combat.records[v.character]==v and not combat.records[a.character])
    assert(v.torso.CanCollide and not v.torso.Massless)
end)
check('server rejects distant carry before changing physics',function()
    local combat,a,v=fixture(7);combat:carry(a,v)
    assert(not a.carrying and not v.carriedBy and v.humanoid.EvaluateStateMachine==true,'Distance validation happened after carry mutation')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Carry regression scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'carry.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
