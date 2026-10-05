"""Run the real spawn/CharacterAdded/Avatar code with only engine APIs replaced.

This cannot simulate Roblox physics. It checks that placement and the R6 death
flags precede a yielding HTTP fetch, and that stale/dead characters never bind.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()

header = r'''
local now, onWait = 100, nil
local function tick() return now end
local function warn() end
local function wait(seconds)
    now = now + (seconds or 0.05)
    if onWait then onWait() end
end
local function signal()
    local callbacks = {}
    return {Connect = function(_, fn)
        callbacks[fn] = true
        return {Disconnect = function() callbacks[fn] = nil end}
    end, fire = function(_, ...)
        for fn in pairs(callbacks) do fn(...) end
    end}
end
local function node(class, name)
    local n = {ClassName=class, Name=name, children={}, attributes={}, Value=0,
        AncestryChanged=signal(), Touched=signal()}
    function n:IsA(wanted)
        return class==wanted or (wanted=='BasePart' and (class=='Part' or class=='SpawnLocation'))
    end
    function n:FindFirstChild(name)
        for _, child in ipairs(self.children) do if child.Name==name then return child end end
    end
    function n:FindFirstChildOfClass(wanted)
        for _, child in ipairs(self.children) do if child.ClassName==wanted then return child end end
    end
    function n:GetChildren() return self.children end
    function n:GetDescendants()
        local all = {}
        local function walk(parent)
            for _, child in ipairs(parent.children) do all[#all+1]=child;walk(child) end
        end
        walk(self);return all
    end
    function n:SetAttribute(key, value) self.attributes[key]=value end
    function n:GetAttribute(key) return self.attributes[key] end
    function n:Destroy() self.Parent=nil;self.destroyed=true end
    function n:SetNetworkOwner(owner) self.owner=owner end
    function n:Clone()
        local clone=node(class, name)
        clone.Enabled=self.Enabled;clone.HoldDuration=self.HoldDuration
        clone.CFrame=self.CFrame
        for _, child in ipairs(self.children) do
            local copied=child:Clone();copied.Parent=clone
        end
        clone.PromptButtonHoldBegan=signal();clone.PromptButtonHoldEnded=signal();clone.Triggered=signal()
        return clone
    end
    return setmetatable(n, {__newindex=function(t,key,value)
        rawset(t,key,value)
        if key=='Parent' and type(value)=='table' then value.children[#value.children+1]=t end
    end})
end
local function attach(parent, child) child.Parent=parent;return child end
local Instance={new=function(class)
    local n=node(class, class)
    return setmetatable(n, {__newindex=function(t, key, value)
        rawset(t,key,value)
        if key=='Parent' and value then value.children[#value.children+1]=t end
    end})
end}
local xyz={};xyz.__index=xyz
function xyz.__mul(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},xyz) end
local function point(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},xyz) end
local CFrame={new=point};local Vector3={new=point}
local Enum={HumanoidHealthDisplayType={AlwaysOff=0}}
local function typeof(value) return type(value) end
local workspace=node('Workspace','Workspace')
local map=attach(workspace,node('Model','Crossroads'))
attach(map,node('StringValue','IsMap'))
local spawns=attach(map,node('Folder','Spawns'))
local spawn=attach(spawns,node('SpawnLocation','Spawn'))
spawn.CFrame=point(228.578598,123.436943,-1407.97974);spawn.Enabled=true
local Players={}
local playerCharacters={}
function Players:GetPlayerFromCharacter(character) return playerCharacters[character] end
function Players:GetPlayers() return {} end
local fetch
function Players:GetHumanoidDescriptionFromUserId(id) return fetch(id) end
local game={GetService=function(_, name) if name=='Players' then return Players else return {} end end}
local script={Parent={Policy='Policy',Ragdoll='Ragdoll',Avatar='Avatar',HitDetection='HitDetection',
    MoveData='MoveData',AnimationTiming='AnimationTiming',PairSystem='PairSystem',WorldData='WorldData'}}
local modules={WorldData={initialMap='Crossroads'}}
local function require(name)
    if name=='PairSystem' then return function() end end
    return modules[name] or {}
end
'''

code = header
for key, filename in [('Policy','Policy.lua'), ('Avatar','Avatar.lua'), ('World','World.lua'), ('Combat','CombatServer.lua'), ('Voting','Voting.lua')]:
    code += '\nmodules[' + repr(key) + '] = (function()\n' + (ROOT / 'Builder/templates/server' / filename).read_text() + '\nend)()\n'

code += r'''
local function fixture()
    local player=node('Player','TestPlayer')
    player.Parent=true;player.UserId=123;player.DisplayName='Test'
    player.CharacterAdded=signal();player.CharacterRemoving=signal();player.Chatted=signal()
    local stats=attach(player,node('Folder','leaderstats'))
    for _, name in ipairs({'Kills','Killstreak','Completions'}) do stats[name]=attach(stats,node('IntValue',name)) end
    player.leaderstats=stats
    local character=node('Model','TestPlayer');character.Parent=workspace;player.Character=character
    local hum=attach(character,node('Humanoid','Humanoid'))
    hum.Health=100;hum.MaxHealth=100;hum.WalkSpeed=16;hum.JumpPower=50;hum.JumpHeight=7.2
    hum.RequiresNeck=true;hum.BreakJointsOnDeath=true;hum.HealthChanged=signal();hum.Died=signal()
    function hum:ApplyDescription(description) self.description=description end
    local root=attach(character,node('Part','HumanoidRootPart'))
    root.CFrame=point(-438,1279,-714);root.Anchored=false
    root.Velocity=point(0,-250,0);root.RotVelocity=point(0,4,0)
    for _, name in ipairs({'Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'}) do attach(character,node('Part',name)) end
    local folder=node('Folder','Protocol')
    local presentation=attach(folder,node('RemoteEvent','event'))
    function presentation:FireAllClients() end
    local errors={}
    function presentation:FireClient(_, _, payload) if payload.text then errors[#errors+1]=payload.text end end
    attach(folder,node('RemoteEvent','action'));attach(folder,node('RemoteFunction','snapshot'))
    local templates=node('Folder','Templates');templates.Prompts=attach(templates,node('Folder','Prompts'))
    local prompts={}
    for i=1,6 do
        prompts[i]='prompt'..i
        local p=attach(templates.Prompts,node('ProximityPrompt',prompts[i]));p.HoldDuration=1;p.Enabled=false
    end
    local config={names={'folder','action','event','snapshot'},prompts=prompts,events={},mapPrompts={}}
    for i=1,15 do config.events[i]='event'..i end
    local combat=modules.Combat.new({folder=folder,config=config},templates)
    local world=modules.World.new(combat,templates)
    return player,character,hum,root,combat,world,errors
end

local player,character,hum,root,combat,world=fixture()
local seen, pending
fetch=function(id)
    assert(id==123)
    seen={anchored=root.Anchored,neck=hum.RequiresNeck,breaks=hum.BreakJointsOnDeath,
        cframe=root.CFrame,velocity=root.Velocity,rot=root.RotVelocity,alreadyBound=combat.players[player]~=nil}
    pending=coroutine.running();coroutine.yield();return {}
end
onWait=function()
    if pending then local resumed=pending;pending=nil;assert(coroutine.resume(resumed)) end
end
combat:bindPlayer(player);onWait=nil
assert(seen.anchored,'Character was free to fall while the avatar HTTP fetch yielded')
assert(seen.neck==false and seen.breaks==false,'R6 neck/death settings were only applied after appearance loading')
assert(math.abs(seen.cframe.X-228.578598)<=3 and math.abs(seen.cframe.Z+1407.97974)<=3,
    'Character was left at the source template coordinates during avatar initialization')
assert(math.abs(seen.cframe.Y-126.436943)<0.001,'Early spawn did not use the source spawn height')
assert(seen.velocity.Y==0 and seen.rot.Y==0,'Spawn kept velocity from a previous fall')
assert(not seen.alreadyBound,'Gameplay became available before appearance finished')
assert(combat.players[player] and hum.Health==100 and not root.Anchored,'Successful preparation did not release a live gameplay character')
print('Spawn regression: original spawn and safe R6 settings precede yielding appearance fetch')

player,character,hum,root,combat,world=fixture()
pending=nil
fetch=function() pending=coroutine.running();coroutine.yield();return {} end
onWait=function()
    player.Character=node('Model','Replacement');player.Character.Parent=workspace
    if pending then local resumed=pending;pending=nil;assert(coroutine.resume(resumed)) end
end
combat:bindPlayer(player);onWait=nil
assert(not combat.players[player] and not hum.description,'Late appearance completion bound/mutated a replaced character')
print('Spawn regression: respawn during appearance fetch cancels the old character')

player,character,hum,root,combat,world=fixture()
fetch=function() hum.Health=0;return {} end
combat:bindPlayer(player)
assert(not combat.players[player] and not hum.description,'A character killed during preparation was bound as live gameplay')
print('Spawn regression: a dead character cannot finish initialization')

player,character,hum,root,combat,world=fixture()
fetch=function() error('HTTP unavailable') end
combat:bindPlayer(player)
assert(combat.players[player] and not root.Anchored,'Avatar HTTP failure left the original R6 body unbound/anchored')
print('Spawn regression: an unavailable avatar service retains the original R6 body')

local disabled=attach(spawns,node('SpawnLocation','Disabled'))
disabled.CFrame=point(0,-1000,0);disabled.Enabled=false
local enabledSpawns=world:spawns()
assert(#enabledSpawns==1 and enabledSpawns[1]==spawn,'Disabled spawn locations were treated as current spawn targets')
table.remove(spawns.children)
print('Spawn regression: disabled spawn locations are not selected')

-- An IsMap-only scan produced the exact startup error seen in Studio. The
-- source name and spawn folder remain enough to identify the original map.
for i,child in ipairs(map.children) do if child.Name=='IsMap' then table.remove(map.children,i);break end end
local selected=modules.World.new(combat,combat.templates)
assert(selected.activeMap==map,'An existing original map without its marker was discarded')
print('Map regression: source name resolves a loaded map with a missing IsMap marker')

-- No active map is also a recoverable startup condition: mount the existing
-- original map template, preserving its source coordinates and children.
workspace.children={}
local maps=attach(combat.templates,node('Folder','Maps'))
local template=attach(maps,map:Clone())
local recovered=modules.World.new(combat,combat.templates)
assert(recovered.activeMap and recovered.activeMap~=template and recovered.activeMap.Parent==workspace,
    'Missing Workspace map was not mounted from the original ServerStorage template')
assert(recovered.activeMap.Name=='Crossroads' and #recovered:spawns()==1)
assert(recovered:spawns()[1].CFrame.Y==123.436943,'Startup recovery replaced the original map spawn coordinates')
assert(#workspace.children==1,'Startup recovery created duplicate active maps')
print('Map regression: empty Workspace mounts the original map template once')

workspace.children={}
local namedCharacter=attach(workspace,node('Model','Crossroads'))
attach(namedCharacter,node('Humanoid','Humanoid'))
local protected=modules.World.new(combat,combat.templates)
assert(not namedCharacter.destroyed and protected.activeMap~=namedCharacter,
    'A character with the initial map name was destroyed/selected as the source map')
print('Map regression: map restoration preserves a same-name humanoid character')

workspace.children={}
local unrelated=attach(workspace,node('Model','Crossroads'))
local existing=attach(workspace,template:Clone())
local found=modules.World.new(combat,combat.templates)
assert(found.activeMap==existing and not unrelated.destroyed and #workspace.children==2,
    'A same-name unrelated model hid the existing source map or was destroyed')
print('Map regression: duplicate names do not hide a valid existing source map')

workspace.children={}
unrelated=attach(workspace,node('Model','Crossroads'))
local alongside=modules.World.new(combat,combat.templates)
assert(not unrelated.destroyed and alongside.activeMap~=unrelated and #workspace.children==2,
    'Source template recovery destroyed an unrelated same-name model')
print('Map regression: original template recovery preserves unrelated same-name models')

-- Voting must use the same map identity rules even while a player character
-- temporarily has no Humanoid during respawn/appearance preparation.
local respawning=attach(workspace,node('Model','Crossroads'))
playerCharacters[respawning]={}
local npc=attach(workspace,node('Model','Crossroads'))
attach(npc,node('Humanoid','Humanoid'))
local oldMap=alongside.activeMap
alongside.chooseWeather=function() end
local vote=modules.Voting.new(combat,alongside,maps)
vote:load('Crossroads')
assert(oldMap.destroyed and alongside.activeMap~=oldMap,'Voting retained the previous source map')
assert(not respawning.destroyed and not npc.destroyed and not unrelated.destroyed,
    'Voting destroyed a player/NPC/unrelated model with an original map name')
print('Map regression: voting replaces only identified source maps and preserves characters')

-- A broken installation still fails with a bounded, concrete diagnostic.
workspace.children={};maps.children={}
local before=now
local ok,why=pcall(modules.World.new,combat,combat.templates)
assert(not ok and tostring(why):find('Crossroads',1,true),'Missing source map did not name its unavailable dependency')
assert(now-before<=5.1,'Missing map dependency caused an unbounded startup wait')
print('Map regression: unavailable source dependencies fail within five seconds')
'''

with tempfile.TemporaryDirectory(dir=ROOT.parent) as tmp:
    target = Path(tmp) / 'spawn.luau'
    target.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(target)], check=True)
