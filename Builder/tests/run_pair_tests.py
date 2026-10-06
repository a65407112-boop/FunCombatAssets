"""Original morph/effect lifecycle checks, without geometry or Roblox physics."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = 'local cleanupFactory, animationsFactory\n' + (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += '\ncleanupFactory=(function()\n' + (ROOT / 'client/cleanup.lua').read_text() + '\nend)()\n'
code += '\nlocal pairFactory=(function()\n' + (ROOT / 'client/pair.lua').read_text() + '\nend)()\n'
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
    local model=node('Model',name);local ref=node('Part','ref');ref.Parent=model
    if name=='TorsoRig' then
        local v=node('Part','v');v.Parent=ref
        local fx=node('Part','InteractionFX');fx.Parent=v
        local attachment=node('Attachment','Attachment');attachment.Parent=fx
        local blood=node('ParticleEmitter','Blood');blood.Texture='rbxassetid://1269254614';blood.Enabled=true;blood.Parent=attachment
        local emitter=node('ParticleEmitter','ParticleEmitter');emitter.Texture='rbxassetid://241576804';emitter.Enabled=false;emitter.Parent=fx
    end
    return model
end
function methods:Emit(n) self.emitted=(self.emitted or 0)+n end
local function fixture()
    local ctx,_,reports,listeners=context();ctx.gui={roots={}};ctx.audio={play=function() end}
    ctx.catalog.costumes={'TorsoRig','LowerRig'}
    local templates={TorsoRig=rig('TorsoRig'),LowerRig=rig('LowerRig')}
    ctx.assets={clone=function(_,key) return templates[assert(key:match('^costumes/(.+)$'))]:Clone() end}
    local a,v=character(),character();a.Name='Female';v.Name='Victim';player.Character=a
    for _,c in ipairs({a,v}) do local root=node('Part','HumanoidRootPart');root.Parent=c;c:FindFirstChild('Torso').Transparency=0 end
    local states={}
    ctx.state.get=function(_,c) return states[c] end
    ctx.state.all=function() return states end
    ctx.state.localState=function() return states[a] end
    local module=pairFactory(ctx)
    return ctx,module,a,v,states,listeners,reports
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
