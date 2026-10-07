"""Trace the real combat chat factory through the real encoded network sender.

Only unavailable Roblox services/signals/UI are doubled. This characterizes
existing routing and cannot certify delivery on a live Roblox server.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--luau',required=True);args=parser.parse_args()
header=(ROOT/'Builder/tests/client_runtime.spec.luau').read_text()
setup=r'''
local Enum={KeyCode={G='G',H='H',J='J',K='K',L='L',Q='Q',Backspace='Backspace'},
    UserInputType={MouseButton1='MouseButton1'}}
local input={InputBegan=signal(),TouchTap=signal(),GetFocusedTextBox=function() return nil end}
local chat={SendingMessage=signal(),DescendantAdded=signal(),GetDescendants=function() return {} end}
player.UserId=11556197791;player.Parent=true;player.Chatted=signal();player.CharacterAdded=signal()
local mouse={Icon='native-icon'};player.GetMouse=function() return mouse end
local originalService=game.GetService
game.GetService=function(self,name)
    if name=='UserInputService' then return input elseif name=='TextChatService' then return chat end
    return originalService(self,name)
end
protocol.actionIds.SpawnDummy='62cc1e80e42b'
local function fixture()
    currentTime=100;fired={};ctx.cleanup=maid()
    local state={character=player.Character,userId=player.UserId,health=100,downed=false,ragdolled=false,busy=false,stunned=false,canAct=true,
        weapon='',attacking=false,revision=1}
    ctx.state={localState=function() return state end,onChanged=function() return function() end end}
    ctx.gui={onAction=function() return function() end end}
    ctx.network=networkFactory(ctx)
    local combat=combatFactory(ctx)
    return combat,state
end
local total=0
local function check(name,fn) fn();total+=1;print('Combat input: '..name) end
'''
checks=r'''
check('legacy ordinary spawn reaches the encoded authoritative action exactly once',function()
    local combat=fixture();player.Chatted:fire('spawn')
    assert(#fired==1 and fired[1][1]=='62cc1e80e42b' and fired[1][2]==nil,'Plain spawn never reached the real network sender')
    combat:destroy();ctx.cleanup:destroy()
end)
check('modern chat reaches the same action with the real numeric avatar ID',function()
    local combat=fixture();chat.SendingMessage:fire({Text='spawn 11556197791'})
    assert(#fired==1 and fired[1][1]=='62cc1e80e42b' and fired[1][2]==11556197791,'Modern chat lost or corrupted the avatar ID')
    combat:destroy();ctx.cleanup:destroy()
end)
check('duplicate modern and legacy callbacks cannot send a second same-frame request',function()
    local combat=fixture();player.Chatted:fire('spawn');chat.SendingMessage:fire({Text='spawn'})
    assert(#fired==1,'One chat input was sent twice')
    combat:destroy();ctx.cleanup:destroy()
end)
check('blocked character and malformed IDs are rejected before transport',function()
    local combat,state=fixture();state.busy=true;player.Chatted:fire('spawn');assert(#fired==0,'Busy character sent a spawn')
    state.busy=false;player.Chatted:fire('spawn -1');player.Chatted:fire('spawn 1.5');player.Chatted:fire('spawn 100000000001');player.Chatted:fire('spawn abc')
    assert(#fired==0,'Malformed dummy avatar ID was transported')
    combat:destroy();ctx.cleanup:destroy()
end)
check('native Kohl aliases are not also executed by external chat input',function()
    local combat=fixture();player.Chatted:fire(':dummy');chat.SendingMessage:fire({Text=':spawndummy'})
    assert(#fired==0,'Native custom command was additionally routed by the client')
    combat:destroy();ctx.cleanup:destroy()
end)
check('teardown disconnects chat owners and stops action delivery',function()
    local combat=fixture();combat:destroy();player.Chatted:fire('spawn');chat.SendingMessage:fire({Text='spawn'})
    assert(#fired==0,'Destroyed runtime retained a chat owner');ctx.cleanup:destroy()
end)
print('Combat input characterization scenarios passed: '..total)
'''
# fixture closes over these locals; declare them before defining fixture.
script=header+'\nlocal networkFactory,combatFactory\n'+setup+'\nnetworkFactory=(function()\n'+(ROOT/'client/networking.lua').read_text()+'\nend)()\n'
script+='combatFactory=(function()\n'+(ROOT/'client/combat.lua').read_text()+'\nend)()\n'+checks
with tempfile.TemporaryDirectory(dir=ROOT) as directory:
    path=Path(directory)/'combat_input.luau';path.write_text(script)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
