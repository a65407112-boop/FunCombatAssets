"""Original morph/effect lifecycle checks, without geometry or Roblox physics."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()

def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(key) + ']=' + lua(item) for key, item in value.items()) + '}'
    raise TypeError(type(value))

# Authored property/reference metadata only; no vertices, mesh payloads, bounds
# extraction or rendering. The actual pair factory consumes these API doubles.
catalog = json.loads((ROOT / 'config/assets.json').read_text())
keys = {'CFrame', 'Size', 'Transparency', 'Scale', 'C0', 'C1', 'Part0', 'Part1',
        'Color', 'Texture', 'Enabled', 'Anchored', 'CanCollide'}
originals = {}
for name in ['TorsoRig', 'LowerRig']:
    data = json.loads((ROOT / catalog['packages']['costumes/' + name]['path']).read_text())
    originals[name] = {'root': data['root'], 'nodes': [
        {'id': node['id'], 'class': node['class'], 'name': node['name'], 'parent': node.get('parent'),
         'properties': {key: value for key, value in node['properties'].items() if key in keys}}
        for node in data['nodes']]}
code = 'local cleanupFactory, animationsFactory\n' + (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += '\ncleanupFactory=(function()\n' + (ROOT / 'client/cleanup.lua').read_text() + '\nend)()\n'
code += '\nlocal pairFactory=(function()\n' + (ROOT / 'client/pair.lua').read_text() + '\nend)()\n'
code += '\nlocal originals=' + lua(originals) + '\n'
code += r'''
local player={CharacterRemoving=signal()}
local originalService=game.GetService
game.GetService=function(_,name)
    if name=='Players' then return {LocalPlayer=player} end
    if name=='UserInputService' then return {InputBegan=signal(),GetFocusedTextBox=function() end} end
    if name=='StarterGui' then return {SetCore=function() end} end
    if name=='TweenService' then return {} end
    return originalService(game,name)
end
local function rig(name)
    local data=assert(originals[name]);local byId={}
    for _,item in ipairs(data.nodes) do byId[item.id]=node(item.class,item.name) end
    for _,item in ipairs(data.nodes) do
        local object=byId[item.id]
        for key,property in pairs(item.properties) do
            local result=property.value
            if property.type=='CFrame' then result=CFrame.new(table.unpack(result))
            elseif property.type=='Vector3' then result=Vector3.new(table.unpack(result))
            elseif property.type=='Color3' then result={R=result[1],G=result[2],B=result[3]}
            elseif property.type=='Ref' then result=result and byId[result] or nil end
            object[key]=result
        end
        if item.parent then object.Parent=byId[item.parent] end
    end
    return assert(byId[data.root]),byId
end
function methods:Emit(n) self.emitted=(self.emitted or 0)+n end
local function fixture()
    local ctx,_,reports,listeners=context();ctx.gui={roots={}};ctx.audio={play=function() end}
    ctx.catalog.costumes={'TorsoRig','LowerRig'}
    local assets={}
    ctx.assets={clone=function(_,key)
        local model,byId=rig(assert(key:match('^costumes/(.+)$')));assets[model]=byId;return model
    end}
    local a,v=character(),character();a.Name='Female';v.Name='Victim';player.Character=a
    for _,c in ipairs({a,v}) do local root=node('Part','HumanoidRootPart');root.Parent=c;c:FindFirstChild('Torso').Transparency=0 end
    local states={}
    ctx.state.get=function(_,c) return states[c] end
    ctx.state.all=function() return states end
    ctx.state.localState=function() return states[a] end
    local module=pairFactory(ctx)
    return ctx,module,a,v,states,listeners,reports,assets
end
local function emitters(character)
    local rig=assert(character:FindFirstChild('TorsoRig'),'Female original TorsoRig was not mounted')
    local fx=assert(rig:FindFirstChild('InteractionFX',true),'Original InteractionFX is missing')
    return fx:FindFirstChild('Attachment'):FindFirstChild('Blood'),fx:FindFirstChildOfClass('ParticleEmitter')
end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Morph/effect: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
for _,mount in ipairs({{'actor','TorsoRig'},{'victim','LowerRig'}}) do
    check(mount[2]..' enters the character with every authored ref-relative CFrame intact',function()
        local ctx,pair,a,v,states,listeners,_,assets=fixture()
        local role,name=table.unpack(mount);local c=role=='actor' and a or v;local captured=false
        local originalModel,authored=rig(name);local originalRef=originalModel:FindFirstChild('ref')
        c.ChildAdded:Connect(function(model)
            if model.Name~=name then return end
            captured=true
            local ref=model:FindFirstChild('ref')
            -- Record metadata at parenting. Original constraints are inactive
            -- outside Workspace; this double runs no native constraint solving
            -- and does not reproduce phone rendering.
            for id,object in pairs(assets[model]) do
                if object:IsA('BasePart') then
                    sameFrame(ref.CFrame:ToObjectSpace(object.CFrame),originalRef.CFrame:ToObjectSpace(authored[id].CFrame))
                end
            end
        end)
        states[c]={character=c,pairRole=role,pairId='authored',pairTag='FD'};pair:apply(states[c])
        assert(captured,'Original morph did not enter its actual character')
        pair:destroy();ctx.cleanup:destroy()
    end)
end
check('source visibility, dimensions, mesh scales and movable Motor offsets are preserved',function()
    local ctx,pair,a,v,states,listeners,_,assets=fixture()
    local mounted={}
    for _,entry in ipairs({{a,'actor','TorsoRig'},{v,'victim','LowerRig'}}) do
        local c,role,name=table.unpack(entry)
        states[c]={character=c,pairRole=role,pairId='source',pairTag='FD'};pair:apply(states[c])
        local model=assert(c:FindFirstChild(name));mounted[#mounted+1]=model
        local _,authored=rig(name);local byId=assets[model];local torso=c:FindFirstChild('Torso')
        for _,item in ipairs(originals[name].nodes) do
            local object,original=byId[item.id],authored[item.id]
            if object:IsA('BasePart') then
                assert(object.Transparency==original.Transparency,'Original morph visibility changed: '..name..'/'..object.Name)
                for _,axis in ipairs({'X','Y','Z'}) do assert(object.Size[axis]==original.Size[axis],'Original part dimensions changed') end
            elseif object:IsA('SpecialMesh') then
                for _,axis in ipairs({'X','Y','Z'}) do assert(object.Scale[axis]==original.Scale[axis],'Authored SpecialMesh.Scale changed') end
            elseif object:IsA('Motor6D') then
                sameFrame(object.C0,original.C0);sameFrame(object.C1,original.C1)
                if original.Parent.Name=='Movables' then
                    assert(object.Parent==torso and object.Part0==torso,'Movable Motor was not bound to the original R6 torso')
                    assert(object.Part1 and object.Part1:IsA('BasePart') and object.Part1.Name==object.Name,'Same-name movable target changed')
                end
            end
        end
        local anchor
        for _,child in ipairs(torso:GetChildren()) do if child:IsA('Weld') and child.Part1==model:FindFirstChild('ref') then anchor=child end end
        assert(anchor and anchor.Part0==torso,'Original torso-to-ref weld missing')
    end
    listeners.Pair({kind='Clear',pairId='source'})
    for _,model in ipairs(mounted) do assert(not model.Parent,'Source morph survived its owner cleanup') end
    assert(a:FindFirstChild('Torso').Transparency==0 and v:FindFirstChild('Torso').Transparency==0,'Original torso visibility did not restore')
    pair:destroy();ctx.cleanup:destroy()
end)
check('female TorsoRig mounts from server role even if the partner Instance has not replicated',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairRole='actor',pairId='one',pairTag='FD'}
    pair:apply(states[a])
    local blood,emitter=emitters(a)
    assert(blood.Texture=='rbxassetid://1269254614' and emitter.Texture=='rbxassetid://241576804','Original effect textures were replaced')
    listeners.Pair({kind='Particles',a=a,v=v,tag='FD',pairId='one',n1=20,n2=10,serverTime=now})
    assert(blood.emitted==20 and emitter.emitted==10,'Female effect was assigned to the wrong participant')
    pair:destroy();ctx.cleanup:destroy()
end)
check('a server burst arriving before streamed torso waits for the original morph',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairVictim=v,pairRole='actor',pairId='one',pairTag='FD'}
    local old=a:FindFirstChild('Torso');old:Destroy();pair:apply(states[a])
    listeners.Pair({kind='Particles',a=a,v=v,tag='FD',pairId='one',n1=20,n2=10,serverTime=now})
    local torso=node('Part','Torso');torso.Transparency=0;torso.Parent=a
    now+=0.1;run.Heartbeat:fire()
    local blood,emitter=emitters(a)
    assert(blood.emitted==20 and emitter.emitted==10,'A streamed spawn silently lost the server effect')
    pair:destroy();ctx.cleanup:destroy()
end)
check('female particles resolve by server role when the actor reference in the burst is temporarily nil',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairRole='actor',pairId='one',pairTag='FD'};pair:apply(states[a])
    listeners.Pair({kind='Particles',v=v,tag='FD',pairId='one',n1=20,n2=10,serverTime=now})
    local blood,emitter=emitters(a)
    assert(blood.emitted==20 and emitter.emitted==10,'Missing actor reference selected the carried male model as the female FX host')
    pair:destroy();ctx.cleanup:destroy()
end)
check('a late burst cannot enter a new interaction between the same players',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairVictim=v,pairRole='actor',pairId='new',pairTag='FD'};pair:apply(states[a])
    listeners.Pair({kind='Particles',a=a,v=v,tag='FD',pairId='old',n1=30,n2=17,serverTime=now})
    run.Heartbeat:fire();local blood,emitter=emitters(a)
    assert(not blood.emitted and not emitter.emitted,'Stale effect crossed into a new server interaction')
    pair:destroy();ctx.cleanup:destroy()
end)
check('Clear removes a replicated female morph even if its actor reference is missing',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairRole='actor',pairId='one',pairTag='FD'};pair:apply(states[a])
    listeners.Pair({kind='Clear',v=v,pairId='one'})
    assert(not a:FindFirstChild('TorsoRig') and a:FindFirstChild('Torso').Transparency==0,'Missing Clear reference leaked the female morph')
    pair:destroy();ctx.cleanup:destroy()
end)
check('stopping an interaction removes its morph and pending bursts',function()
    local ctx,pair,a,v,states,listeners=fixture()
    states[a]={character=a,pairVictim=v,pairRole='actor',pairId='one',pairTag='FD'}
    a:FindFirstChild('Torso'):Destroy();pair:apply(states[a])
    listeners.Pair({kind='Particles',a=a,v=v,tag='FD',pairId='one',n1=20,n2=10,serverTime=now})
    listeners.Pair({kind='Clear',a=a,v=v,pairId='one'})
    states[a]={character=a}
    local torso=node('Part','Torso');torso.Transparency=0;torso.Parent=a;run.Heartbeat:fire()
    assert(not a:FindFirstChild('TorsoRig') and torso.Transparency==0,'Stopped effect restored a stale morph')
    pair:destroy();ctx.cleanup:destroy()
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Original morph/effect regression scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'pair.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
