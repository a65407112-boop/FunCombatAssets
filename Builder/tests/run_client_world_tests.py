"""Exercise world entry and local visibility without loading any morph assets."""
import argparse
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--luau', required=True)
args = p.parse_args()
code = (ROOT/'Builder/tests/presentation_runtime.spec.luau').read_text()
code += r'''
local makeNode=node
node=function(class,name)
    local n=makeNode(class,name)
    n.DescendantAdded=signal();n.Changed=signal();n.attributeSignals={};n.propertySignals={}
    local mt=getmetatable(n);local assign=mt.__newindex
    mt.__newindex=function(self,key,value)
        local before=self[key];assign(self,key,value)
        if before~=value and self.propertySignals[key] then self.propertySignals[key]:fire() end
        if before~=value then self.Changed:fire(key) end
        if key=='Parent' and value then
            local parent=value
            while type(parent)=='table' and parent.kind=='Instance' do
                parent.DescendantAdded:fire(self);parent=parent.Parent
            end
        end
    end
    return n
end
local isa=methods.IsA
function methods:IsA(class) return isa(self,class) or class=='BasePart' and self.ClassName=='SpawnLocation' end
function methods:GetAttributeChangedSignal(key)
    self.attributeSignals[key]=self.attributeSignals[key] or signal();return self.attributeSignals[key]
end
function methods:GetPropertyChangedSignal(key)
    self.propertySignals[key]=self.propertySignals[key] or signal();return self.propertySignals[key]
end
function methods:IsDescendantOf(ancestor)
    local current=self.Parent
    while type(current)=='table' do
        if current==ancestor then return true end
        current=current.Parent
    end
    return false
end
function methods:SetAttribute(key,value)
    local before=self.attributes[key];self.attributes[key]=value
    if before~=value and self.attributeSignals[key] then self.attributeSignals[key]:fire() end
end
local workspace=node('Workspace','Workspace')
local run={Heartbeat=signal()}
local players={all={},PlayerAdded=signal(),PlayerRemoving=signal()}
function players:GetPlayers() return self.all end
function players:GetPlayerFromCharacter(character)
    for _,player in ipairs(self.all) do if player.Character==character then return player end end
end
local services={Players=players,RunService=run,Workspace=workspace}
game.GetService=function(_,name) return assert(services[name],name) end
local Instance={new=function(class) return node(class,class) end}
local function attach(parent,child) child.Parent=parent;return child end
local function person(id)
    local p=node('Player','Player'..id);p.UserId=id;p.Parent=true
    p.CharacterAdded=signal();p.CharacterRemoving=signal()
    local c=attach(workspace,node('Model',p.Name));p.Character=c
    local root=attach(c,node('Part','HumanoidRootPart'));root.CFrame=CFrame.new(0,-20,0)
    root.LocalTransparencyModifier=0;root.Anchored=false
    local hum=attach(c,node('Humanoid','Humanoid'));hum.DisplayDistanceType='Viewer'
    players.all[#players.all+1]=p
    return p,root
end
local first,firstRoot=person(10);local second,secondRoot=person(20)
players.LocalPlayer=first
local room=attach(workspace,node('Model','room_alias'))
local roomSpawn=attach(room,node('SpawnLocation','room_spawn_alias'));roomSpawn.CFrame=CFrame.new(0,1002,0)
local net=attach(workspace,node('Folder','Protocol'));services.ReplicatedStorage=workspace
local map=attach(workspace,node('Model','map_alias'))
local moving=attach(map,node('Part','moving'));moving:SetAttribute('world_node_alias',2)
moving.Anchored=false;moving.CFrame=CFrame.new(50,60,70)
local world={activeMap=map}
local placed=0
function world:spawn(record)
    placed+=1;record.root.CFrame=CFrame.new(50,63,70);record.root.Velocity=Vector3.new();return true
end
local config={version=1,remote='session_alias',readyAttribute='ready_alias',nodeAttribute='world_node_alias',
    room='room_alias',spawn='room_spawn_alias',lease=15,maps={map_alias='world/Crossroads',other_map='world/OriginalMap'}}
'''
code += '\nlocal Session=(function()\n'+(ROOT/'Builder/templates/server/ClientWorldSession.lua').read_text()+'\nend)()\n'
code += r'''
local session=Session.start(world,net,'test-build',config)
local remote=assert(net:FindFirstChild('session_alias'))
local sessions={}
local function request(player,op,extra)
    if not sessions[player] then
        local opened=remote.OnServerInvoke(player,{op='open',buildId='test-build'})
        assert(opened.accepted and type(opened.session)=='number','World session identity was not issued')
        sessions[player]=opened.session
    end
    local data={op=op,buildId='test-build',session=sessions[player]}
    for k,v in pairs(extra or {}) do data[k]=v end
    local result=remote.OnServerInvoke(player,data)
    if op=='leave' then sessions[player]=nil end
    return result
end
sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
assert(first.RespawnLocation==roomSpawn and first:GetAttribute('ready_alias')==false,'Ordinary join lacks safe room spawn')
world:spawn({root=firstRoot,player=first});sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
local invalid=remote.OnServerInvoke(first,{op='join',buildId='bad',revision=1,mapKey='world/Crossroads'})
assert(not invalid.accepted and placed==0,'Wrong build authorized map entry')
local status=request(first,'status')
assert(status.mapKey=='world/Crossroads' and not status.joined)
local stale=request(first,'join',{revision=status.revision+1,mapKey=status.mapKey})
assert(not stale.accepted and placed==0,'Stale map revision authorized entry')
local joined=request(first,'join',{revision=status.revision,mapKey=status.mapKey})
assert(joined.accepted and first:GetAttribute('ready_alias')==true)
sameFrame(firstRoot.CFrame,CFrame.new(50,63,70))
request(first,'join',{revision=status.revision,mapKey=status.mapKey})
assert(placed==1,'Repeated join teleported an already participating player')
world:spawn({root=firstRoot});assert(placed==2,'Native pre-bind spawn could not resolve its owning player')
request(first,'leave');sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
assert(first:GetAttribute('ready_alias')==false)
local abandoned=joined.session
assert(not remote.OnServerInvoke(first,{op='join',buildId='test-build',session=abandoned,
    revision=status.revision,mapKey=status.mapKey}).accepted,'A revoked loader request rejoined after leave')
request(first,'join',{revision=status.revision,mapKey=status.mapKey})
assert(not remote.OnServerInvoke(first,{op='leave',buildId='test-build',session=abandoned}).accepted
    and first:GetAttribute('ready_alias')==true,'An old loader closed a newer loader session')
now+=16;run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==false,'Expired loader session remains on the map')
sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
request(first,'join',{revision=status.revision,mapKey=status.mapKey})
world.activeMap=attach(workspace,node('Model','other_map'));run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==false,'Map switch kept obsolete readiness')
sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
local changed=request(first,'status');assert(changed.revision>status.revision and changed.mapKey=='world/OriginalMap')
assert(not request(first,'join',{revision=status.revision,mapKey=status.mapKey}).accepted)
world.activeMap=map;run.Heartbeat:fire(1)
'''
for name in ['cleanup','participants','world']:
    code += '\nlocal '+name+'Factory=(function()\n'+(ROOT/'client'/f'{name}.lua').read_text()+'\nend)()\n'
code += r'''
Enum.HumanoidDisplayDistanceType={None='None'}
local ctx={protocol={clientWorld=config,names={Folder='Protocol'}},manifest={buildId='test-build'},identifiers={objectNames={}},
    config={Timeout=2},report=function(message) error(message) end}
ctx.cleanup=cleanupFactory(ctx)
ctx.participants=participantsFactory(ctx)
ctx.participants:setActive(true)
assert(secondRoot.LocalTransparencyModifier==1,'Non-participating player remained visible')
local extra=attach(second.Character,node('Part','LatePart'));extra.LocalTransparencyModifier=0
-- The part may be configured by another script immediately after parenting.
assert(extra.LocalTransparencyModifier==1,'Late or subsequently changed character part remained visible')
second:SetAttribute('ready_alias',true)
assert(secondRoot.LocalTransparencyModifier==0 and extra.LocalTransparencyModifier==0,'Participant remained hidden')
second:SetAttribute('ready_alias',false)
assert(secondRoot.LocalTransparencyModifier==1)
assert(firstRoot.LocalTransparencyModifier==0,'Local player was hidden')
local downloaded=0;local failed=false
local staticA=attach(workspace,node('Part','same_alias'));staticA:SetAttribute('world_node_alias',3)
staticA.CFrame=CFrame.new(10,20,30);staticA.Anchored=false
local staticB=attach(workspace,node('Part','same_alias'));staticB:SetAttribute('world_node_alias',4)
staticB.CFrame=CFrame.new(40,50,60);staticB.Anchored=false
config.staticAsset='world/Environment'
config.staticRoots={{alias='same_alias',nodeId=3},{alias='same_alias',nodeId=4}}
ctx.assets={clone=function(_,key)
    if key=='world/Environment' then
        local copy=node('Folder','Environment')
        for id=3,4 do
            local p=attach(copy,node('Part','Static'..id));p:SetAttribute('world_node_alias',id)
            p.CFrame=CFrame.new();p.CanCollide=true;p.Anchored=false
        end
        return copy
    end
    if failed then error('download failed') end
    downloaded+=1
    local copy=node('Model','DownloadedMap')
    local p=attach(copy,node('Part','VisibleMoving'));p:SetAttribute('world_node_alias',2)
    p.CFrame=CFrame.new();p.CanCollide=true;p.Anchored=false
    return copy
end}
function remote:InvokeServer(data)
    if data.op=='join' then
        assert(workspace:FindFirstChild('FunCombat_ClientWorld'),'Join occurred before visible map was mounted')
    end
    return self.OnServerInvoke(first,data)
end
ctx.world=worldFactory(ctx)
local staticVisible=assert(workspace:FindFirstChild('FunCombat_ClientEnvironment'))
sameFrame(staticVisible:FindFirstChild('Static3').CFrame,staticA.CFrame)
sameFrame(staticVisible:FindFirstChild('Static4').CFrame,staticB.CFrame)
assert(downloaded==1 and first:GetAttribute('ready_alias')==false,'World initialization joined before full loader readiness')
ctx.world:activate()
assert(first:GetAttribute('ready_alias')==true,'Successful initialized map failed to join')
local visible=workspace:FindFirstChild('FunCombat_ClientWorld')
local visiblePart=visible:FindFirstChild('VisibleMoving',true)
assert(visiblePart.CanCollide==false and visiblePart.Anchored==true,'Visual clone introduced divergent physics')
moving.CFrame=CFrame.new(71,72,73);run.Heartbeat:fire(.1)
sameFrame(visiblePart.CFrame,moving.CFrame)
-- A failed next-map import returns the player to the room and removes old visuals.
world.activeMap=attach(workspace,node('Model','other_map'));failed=true
ctx.report=function() end
now+=2;run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==false,'Failed map import left player active')
sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
assert(not workspace:FindFirstChild('FunCombat_ClientWorld'),'Failed map import left obsolete map visuals')
assert(secondRoot.LocalTransparencyModifier==0,'Failed world load kept room occupants locally hidden')
failed=false;now+=2;run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==true,'Map reload did not recover after a transient failure')
assert(secondRoot.LocalTransparencyModifier==1,'World reentry did not resume participant visibility')
local invoke=remote.InvokeServer
local disconnected=true
function remote:InvokeServer(data)
    if disconnected then error('network unavailable') end
    return invoke(self,data)
end
now+=16;run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==false and secondRoot.LocalTransparencyModifier==0,
    'Network loss and lease expiry did not restore waiting-room visibility')
sameFrame(firstRoot.CFrame,CFrame.new(0,1006,0))
disconnected=false;now+=2;run.Heartbeat:fire(1)
assert(first:GetAttribute('ready_alias')==true,'Reconnection failed to create a fresh world session')
local cancelledJoin=false
local beforeCancellationDownloads=downloaded
function remote:InvokeServer(data)
    if data.op=='status' then
        local result=invoke(self,data)
        ctx.cleanup:destroy()
        return result -- completed old status is delivered after cleanup's leave
    end
    if data.op=='join' and ctx.cleanup.dead then
        cancelledJoin=true
        return self.OnServerInvoke(first,data)
    end
    return invoke(self,data)
end
now+=2;run.Heartbeat:fire(1)
assert(not cancelledJoin and first:GetAttribute('ready_alias')==false,
    'A completed stale status joined after the loader was destroyed')
assert(downloaded==beforeCancellationDownloads,'Cancelled work fetched another map after cleanup')
ctx.cleanup:destroy()
assert(first:GetAttribute('ready_alias')==false,'Unload did not leave shared world')
assert(secondRoot.LocalTransparencyModifier==0,'Unload did not restore locally hidden players')
assert(not workspace:FindFirstChild('FunCombat_ClientWorld'),'Unload left a duplicate visual map')
print('Client world: safe entry, build/revision checks, lease, map changes, local visibility, failed load and cleanup passed')
'''
with tempfile.TemporaryDirectory(dir=ROOT.parent) as directory:
    path=Path(directory)/'client-world.luau';path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
