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
        AncestryChanged=signal(), Touched=signal(), ChildAdded=signal(), ChildRemoved=signal()}
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
    function n:IsDescendantOf(parent)
        local current=self.Parent
        while type(current)=='table' do
            if current==parent then return true end
            current=current.Parent
        end
        return false
    end
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
function Players:GetHumanoidDescriptionFromUserId(id)
    local result=fetch(id)
    -- Roblox returns an Instance, including when there are no description children.
    if not result.GetChildren then
        local description=node('HumanoidDescription','Description')
        for key,value in pairs(result) do description[key]=value end
        return description
    end
    return result
end
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
for key, filename in [('Policy','Policy.lua'), ('Ragdoll','Ragdoll.lua'), ('Avatar','Avatar.lua'), ('World','World.lua'), ('Combat','CombatServer.lua'), ('Voting','Voting.lua')]:
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
    local settings=attach(templates,node('Configuration','WorldSettings'))
    local dummyFlag=attach(settings,node('BoolValue','AllowDummys'));dummyFlag.Value=true
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
-- Roblox fires CharacterAdded before parenting the new model to Workspace.
-- The real handler must await mounting rather than treating Parent=nil as
-- cancellation and leaving the original anchored template stuck forever.
character.Parent=nil;root.Anchored=true
local fetchedBeforeMount=false
fetch=function()
    fetchedBeforeMount=not character:IsDescendantOf(workspace)
    return {}
end
onWait=function() character.Parent=workspace end
combat:bindPlayer(player);onWait=nil
assert(combat.players[player] and not root.Anchored and not fetchedBeforeMount,
    'CharacterAdded before Workspace mounting was abandoned with an anchored player')
print('Spawn regression: a newly added unparented character waits for Workspace and becomes playable')

player,character,hum,root,combat,world=fixture()
character.Parent=nil;root.Anchored=true
local fetched=false
fetch=function() fetched=true;return {} end
onWait=function() player.Character=node('Model','Replacement') end
combat:bindPlayer(player);onWait=nil
assert(not combat.players[player] and not fetched,
    'A character replaced before Workspace mounting still initialized')
print('Spawn regression: a replaced unparented character cannot finish delayed mounting')

local errors
player,character,hum,root,combat,world,errors=fixture()
character.Parent=nil;root.Anchored=true
fetched=false
fetch=function() fetched=true;return {} end
local awaitStarted=now
combat:bindPlayer(player)
assert(not combat.players[player] and not fetched and #errors==1 and now-awaitStarted<=10.1,
    'A character that never mounts did not fail with a bounded explicit initialization error')
print('Spawn regression: a character that never mounts fails within ten seconds')

player,character,hum,root,combat,world=fixture()
local fetched=0
fetch=function() fetched+=1;error('Native player startup must not fetch account appearance') end
local head=character:FindFirstChild('Head')
head.TextureID='native-dynamic-head'
local torso=character:FindFirstChild('Torso');torso.Color='morph-color'
combat:bindPlayer(player)
assert(combat.players[player] and hum.Health==100 and not root.Anchored,'Native R6 spawn did not become playable')
assert(fetched==0 and not hum.description and character:FindFirstChild('Head')==head and torso.Color=='morph-color',
    'Combat initialization overwrote a native avatar or existing morph')
assert(hum.RequiresNeck==false and hum.BreakJointsOnDeath==false,'Combat death settings were not initialized')
assert(math.abs(root.CFrame.X-228.578598)<=3 and math.abs(root.CFrame.Z+1407.97974)<=3,
    'Native character did not use the original enabled spawn')
assert(root.Velocity.Y==0 and root.RotVelocity.Y==0,'Spawn retained falling velocity')
print('Native spawn: original placement, unanchored body and preserved head/morph without HTTP')

player,character,hum,root,combat,world=fixture()
hum.Health=0
fetch=function() error('No account appearance needed') end
combat:bindPlayer(player)
assert(not combat.players[player] and not root.Anchored,'Dead native character entered gameplay or stayed anchored')
print('Native spawn: dead character cannot initialize gameplay')

player,character,hum,root,combat,world=fixture()
local missing=character:FindFirstChild('Left Arm')
for i,child in ipairs(character.children) do if child==missing then table.remove(character.children,i);break end end
missing.Parent=nil
local premature=combat:bind(character,player)
assert(not premature and not combat.players[player],'Incomplete R6 body entered combat before its limb arrived')
local delayed=false
onWait=function()
    if not delayed then
        delayed=true;assert(not combat.players[player],'CharacterAdded bound before all R6 body parts arrived')
        missing.Parent=character
    end
end
combat:bindPlayer(player);onWait=nil
assert(combat.players[player] and combat.players[player].parts['Left Arm']==missing,
    'Late limb was not included in complete R6 combat bindings')
print('R6 readiness: incomplete startup waits for all body parts and tracks late limbs')

player,character,hum,root,combat,world=fixture()
combat:bindPlayer(player)
local before=assert(combat.players[player]);before.weapon='Sword';player:SetAttribute('Gender','Male')
local oldTorso=character:FindFirstChild('Torso')
for i,child in ipairs(character.children) do if child==oldTorso then table.remove(character.children,i);break end end
oldTorso.Name='RetiredTorso';oldTorso.Parent=nil
oldTorso.Name='Torso';character.ChildRemoved:fire(oldTorso)
assert(not combat:alive(before),'An incomplete morph remained available for combat')
hum.WalkSpeed=0
local replacement=attach(character,node('Part','Torso'));replacement.CFrame=point(700,400,900)
local previousRoot=root.CFrame
character.ChildAdded:fire(replacement)
local after=assert(combat.players[player])
assert(after~=before and before.removed and after.torso==replacement,'In-place R6 morph kept detached combat body bindings')
assert(after.weapon=='Sword' and player:GetAttribute('Gender')=='Male','Morph refresh lost equipment or gender state')
assert(after.walkSpeed==16 and hum.WalkSpeed==16,'Morph retained a temporary combat movement lock as its base speed')
assert(root.CFrame==previousRoot,'In-place morph unexpectedly teleported to spawn')
assert(#replacement.children==6,'Morph refresh did not rebuild one set of gameplay prompts')
local held=after
local hat=attach(character,node('Accessory','NewHat'));character.ChildAdded:fire(hat)
assert(combat.players[player]==held,'An accessory arrival unnecessarily reset combat')
print('Morph binding: replaced R6 parts refresh gameplay and prompts without losing appearance/equipment or teleporting')

player,character,hum,root,combat,world=fixture()
combat:bindPlayer(player)
local bouncing=assert(combat.players[player])
bouncing.wallBounce=true;bouncing.busy=true;bouncing.wallUntil=now+1.5;root.Anchored=true
local oldHead=character:FindFirstChild('Head');oldHead.Name='PreviousHead';oldHead.Parent=nil
local newHead=attach(character,node('Part','Head'));character.ChildAdded:fire(newHead)
local refreshed=assert(combat.players[player])
assert(refreshed~=bouncing and not root.Anchored,'Morph during wall bounce permanently retained the anchored root')
assert(not refreshed.wallBounce and not refreshed.wallUntil and not refreshed.busy,
    'Morph retained an abandoned wall-bounce gameplay lock')
print('Wall bounce: morph cleanup releases anchored roots and transient locks')

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
local function worldModels()
    local result={};for _,object in ipairs(workspace:GetChildren()) do if object:IsA('Model') then result[#result+1]=object end end;return result
end
assert(#worldModels()==1,'Startup recovery created duplicate active maps')
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
assert(found.activeMap==existing and not unrelated.destroyed and #worldModels()==2,
    'A same-name unrelated model hid the existing source map or was destroyed')
print('Map regression: duplicate names do not hide a valid existing source map')

workspace.children={}
unrelated=attach(workspace,node('Model','Crossroads'))
local alongside=modules.World.new(combat,combat.templates)
assert(not unrelated.destroyed and alongside.activeMap~=unrelated and #worldModels()==2,
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
