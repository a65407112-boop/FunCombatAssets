"""Exercise the manual dummy probe; engine APIs are doubled, no Roblox claim."""
import argparse
import ast
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
# Reuse the existing UI/Instance double, including its geometry-read guard.
tree = ast.parse((ROOT / 'Builder/tests/run_diagnostics_tests.py').read_text())
header = next(ast.literal_eval(n.value) for n in tree.body
              if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'header' for t in n.targets))
header = header.replace("local function tick() return 100 end", "local clock,pending=100,{}\nlocal function tick() return clock end")
header = header.replace("local function wait() error('Standalone diagnostics must not wait') end", "local function wait(seconds) return coroutine.yield(seconds) end")
# Connected observers must really disappear on close, expiry and rerun.
header = header.replace("callbacks[#callbacks+1]=callback;return {Disconnect=function() end}",
                        "local slot={callback=callback};callbacks[#callbacks+1]=slot;return {Disconnect=function() slot.callback=nil end}")
header = header.replace("for _,callback in ipairs(callbacks) do callback(...) end", "for _,slot in ipairs(callbacks) do if slot.callback then slot.callback(...) end end")
extra = r'''
local function launch(fn)
    local co=coroutine.create(fn)
    local ok,seconds=coroutine.resume(co);assert(ok,seconds)
    if coroutine.status(co)~='dead' then pending[#pending+1]={co=co,at=clock+seconds} end
end
local function advance(seconds)
    clock+=seconds
    local list=pending;pending={}
    for _,job in ipairs(list) do
        if job.at<=clock then
            local ok,delay=coroutine.resume(job.co);assert(ok,delay)
            if coroutine.status(job.co)~='dead' then pending[#pending+1]={co=job.co,at=clock+delay} end
        else pending[#pending+1]=job end
    end
end
-- Launch the actual chunk's coroutine as Roblox would; this is the only
-- scheduling adaptation in the chunk's environment.
local coroutine={wrap=function(fn) return function(...) launch(function() fn(...) end) end end}
local requests,kaiQueries,presentation,kaiRemote,runtime
local function probeFixture()
    local player,character=uiFixture();clock=100;pending={};requests={};kaiQueries={}
    local world=node('Workspace');services.Workspace=world
    local config=append(world,node('Configuration','Configuration'))
    local flag=append(config,node('BoolValue','AllowDummys'));flag.Value=true;flag.props.readOnly=true
    character:FindFirstChildOfClass('Humanoid').Health=100
    local state={character=character,userId=player.UserId,health=100,downed=false,busy=false,stunned=false,ragdolled=false,canAct=true,revision=1}
    local states={[character]=state}
    kaiRemote=services.ReplicatedStorage:FindFirstChild('b\a\n\a\n\a')
    kaiRemote.OnClientEvent=signal();kaiRemote.FireServer=function(_,name)
        kaiQueries[#kaiQueries+1]=name
        assert(name=='KuID','Probe invoked an admin command instead of reading its registry')
        kaiRemote.OnClientEvent:Fire('KuID',{'123',{}, {Prefix=':',CommandBar=true,FunCommands=true},{{{'clone'},{'Clone','me'},2,{'player'}},{{'dummy','spawndummy'},{'Combat dummy','[userId]'},5,{'number/'}}},{},{}})
    end
    local folder=append(services.ReplicatedStorage,node('Folder','test-folder'))
    presentation=append(folder,node('RemoteEvent','test-events'));presentation.OnClientEvent=signal()
    local version=append(folder,node('IntValue','test-version'));version.Value=4
    local build=append(folder,node('StringValue','test-build'));build.Value='actual-build'
    local action=append(folder,node('RemoteEvent','test-action'));action.FireServer=function() error('Probe bypassed real combat validation') end
    runtime={initialized=true,cancelled=false,cleanup={dead=false},manifest={buildId='actual-build'},
        protocol={version=4,buildId='actual-build',names={Folder='test-folder',Presentation='test-events',Action='test-action',Version='test-version',BuildId='test-build'},
            eventIds={State='test-state',Error='test-error'},actionIds={SpawnDummy='test-spawn'}},
        state={localState=function() return state end,all=function() return states end},
        combat={request=function(_,name,payload) requests[#requests+1]={name,payload};return true end}}
    environment.FunCombat_ExternalRuntime=runtime
    return flag,state,states,player
end
local function probe()
    runDummyProbe()
    local gui=assert(environment.FunCombatDummyDiagnosticsGUI,'Manual probe window missing')
    local button=assert(gui:FindFirstChild('TestDummy',true),'No explicit test button')
    return environment.FunCombatDummyDiagnostics,gui,button
end
'''
# Lua nested varargs need packing for the scheduler wrapper.
extra = extra.replace("return function(...) launch(function() fn(...) end) end", "return function(...) local args=table.pack(...);launch(function() fn(table.unpack(args,1,args.n)) end) end")
checks = r'''
check('opening the probe sends no game actions or registry queries',function()
    probeFixture();local report=probe()
    assert(#requests==0 and #kaiQueries==0 and report.probe.status=='not_started','Merely opening diagnostics caused network work')
end)
check('an actual false admin grant is preserved rather than labelled unavailable',function()
    local _,_,_,player=probeFixture();player.attributes.FunCombatAdminAllowed=false
    local report=probe()
    assert(report.user.FunCombatAdminAllowed==false,'A real false admin grant was confused with a protected/missing value')
end)
check('one button click reads actual native command registration and requests one normal dummy',function()
    local flag,state=probeFixture();local report,gui,button=probe();button.MouseButton1Click:Fire()
    button.MouseButton1Click:Fire();advance(8.1)
    assert(#requests==1 and requests[1][1]=='SpawnDummy' and requests[1][2]==nil,'Probe bypassed the input owner or spawned duplicates')
    assert(#kaiQueries==1 and report.kohlRegistry.received and report.kohlRegistry.dummy and report.kohlRegistry.spawndummy,
        'Actual native registration was not recorded')
    assert(report.kohlRegistry.prefix==':' and report.probe.clientRequestAccepted==true,'Registry prefix or local request result missing')
    assert(report.probe.status=='no_server_result_observed','FireServer acceptance was falsely certified as successful creation')
    assert(flag.Value and state.canAct,'Probe changed game configuration or player state')
    setclipboard=function(text) clipboardText=text end
    gui:FindFirstChild('Copy',true).MouseButton1Click:Fire()
    assert(clipboardText==environment.FunCombatDummyDiagnosticsText,'Copy returned the stale pre-test report')
end)
check('missing native custom commands are distinct from a registry timeout',function()
    probeFixture();kaiRemote.FireServer=function()
        kaiRemote.OnClientEvent:Fire('KuID',{'123',{}, {Prefix='!',CommandBar=true,FunCommands=true},{{{'clone'},{'Clone','me'},2,{'player'}}},{},{}})
    end
    local report,_,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    assert(report.kohlRegistry.received and report.kohlRegistry.dummy==false and report.kohlRegistry.spawndummy==false and report.kohlRegistry.prefix=='!',
        'Missing custom registration was silently assumed present')
    probeFixture();kaiRemote.FireServer=function() end
    report,_,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    assert(report.kohlRegistry.received==false and report.kohlRegistry.status=='no_reply','No registry reply was treated as an empty confirmed list')
end)
check('local request rejection keeps actual blocking state without sending a raw action',function()
    local _,state=probeFixture();state.busy=true;state.canAct=false
    runtime.combat.request=function() return false end
    local report,_,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    assert(report.probe.clientRequestAccepted==false and report.probe.status=='client_rejected' and report.before.localState.busy and not report.before.localState.canAct,
        'Rejected local request or blocking state was lost')
end)
check('actual protocol mismatch blocks spawning',function()
    probeFixture();services.ReplicatedStorage:FindFirstChild('test-folder'):FindFirstChild('test-build').Value='older-live-server'
    local report,_,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    assert(#requests==0 and report.probe.status=='protocol_mismatch','Probe dispatched into a mismatched live server')
end)
check('raw server errors remain visible even when the runtime deduplicates them',function()
    probeFixture();local report,_,button=probe();button.MouseButton1Click:Fire()
    presentation.OnClientEvent:Fire('test-error',{text='Dummy limit: 4 per player, 20 per server',serverTime=101})
    advance(8.1)
    assert(#report.serverErrors==1 and report.serverErrors[1].text:find('Dummy limit',1,true),'Exact raw server refusal was hidden')
end)
check('server NPC observations do not claim an uncorrelated request ownership',function()
    local _,_,states=probeFixture();local previous=node('Model','ExistingRig');previous.Parent=true
    states[previous]={character=previous,userId=0,health=100}
    local report,_,button=probe();button.MouseButton1Click:Fire()
    presentation.OnClientEvent:Fire('test-state',states[previous])
    local model=node('Model','Rig');model.Parent=true
    presentation.OnClientEvent:Fire('test-state',{character=model,userId=0,health=100,displayName='Rig',revision=1,canAct=true})
    advance(8.1)
    assert(#report.newServerNPCs==1 and report.probe.status=='server_npc_observed' and report.probe.ownershipConfirmed==false,
        'Old NPC was counted as a spawn, or an uncorrelated broadcast certified request ownership')
end)
check('close and rerun cancel observers and stale report updates',function()
    probeFixture();local old,gui,button=probe();button.MouseButton1Click:Fire()
    gui:FindFirstChild('Close',true).MouseButton1Click:Fire()
    local new=probe()
    presentation.OnClientEvent:Fire('test-error',{text='late error'})
    advance(8.1)
    assert(#old.serverErrors==0 and new.probe.status=='not_started' and environment.FunCombatDummyDiagnostics==new,'Stale observers damaged a new probe')
end)
check('a delayed scheduler cannot accept observations after the deadline',function()
    probeFixture();kaiRemote.FireServer=function() end
    local report,_,button=probe();button.MouseButton1Click:Fire()
    clock+=8.1 -- advance real time without yet resuming the expiry coroutine
    presentation.OnClientEvent:Fire('test-error',{text='after deadline'})
    kaiRemote.OnClientEvent:Fire('KuID',{'123',{}, {Prefix=':'},{{{'dummy'},{'Dummy'},5,{'number/'}}},{},{}})
    advance(0)
    assert(#report.serverErrors==0 and not report.kohlRegistry.received and report.kohlRegistry.status=='no_reply',
        'Late scheduler allowed observations outside the finite test window')
end)
check('rerunning an active probe cancels old observers without needing Close',function()
    probeFixture();local old,oldGUI,button=probe();button.MouseButton1Click:Fire()
    local fresh=probe()
    presentation.OnClientEvent:Fire('test-error',{text='old observer still alive'})
    advance(8.1)
    assert(oldGUI.props.destroyed and #old.serverErrors==0 and fresh.probe.status=='not_started' and environment.FunCombatDummyDiagnostics==fresh,
        'An actively replaced window retained observers or overwrote the fresh report')
end)
check('normal expiry stops future event capture',function()
    probeFixture();local report,_,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    presentation.OnClientEvent:Fire('test-error',{text='after expiry'})
    assert(#report.serverErrors==0 and report.probe.status=='no_server_result_observed','Expired probe retained a live observer')
end)
check('no runtime and clipboard denial still produce a selectable report',function()
    probeFixture();environment.FunCombat_ExternalRuntime=nil;setclipboard=function() error('clipboard denied') end
    local report,gui,button=probe();button.MouseButton1Click:Fire();advance(8.1)
    assert(#requests==0 and report.probe.status=='client_unavailable','Missing external runtime was hidden or bypassed')
    gui:FindFirstChild('Copy',true).MouseButton1Click:Fire()
    assert(gui:FindFirstChild('Details',true).props.focused and gui:FindFirstChild('Status',true).Text:find('clipboard denied',1,true),
        'Copy failure removed the manual fallback')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Manual dummy probe regression scenarios passed: '..total)
'''
source_path = ROOT / 'diagnose_dummy.lua'
source = source_path.read_text() if source_path.exists() else 'return nil'
script = 'local runDummyProbe\n' + header + extra + '\nrunDummyProbe=function()\n' + source + '\nend\n' + checks
with tempfile.TemporaryDirectory(dir=ROOT) as directory:
    path = Path(directory) / 'dummy_probe.luau'
    path.write_text(script)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
