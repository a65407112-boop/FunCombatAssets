"""Run the actual avatar-content factory with Roblox signals/downloads doubled.

The checks establish request coverage and lifecycle, never CDN availability or
engine rendering. No avatar appearance properties are changed by the factory.
"""
import argparse
import json
import sys
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT / 'Builder'))
from build import lua
bindings=json.loads((ROOT / 'config/identifiers.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
header = r'''
local now,scheduled=100,{}
local function tick() return now end
local function wait(seconds)
    scheduled[#scheduled+1]={at=now+(seconds or 0.05),thread=coroutine.running()}
    coroutine.yield()
end
local function advance(seconds)
    local target=now+seconds;local steps=0
    while true do
        local index
        for i,job in ipairs(scheduled) do
            if job.at<=target and (not index or job.at<scheduled[index].at) then index=i end
        end
        if not index then break end
        local job=table.remove(scheduled,index);now=job.at;steps+=1
        assert(steps<2000,'Avatar preparation scheduled an unbounded busy loop')
        local ok,why=coroutine.resume(job.thread);assert(ok,why)
    end
    now=target
end
local function typeof(value) return type(value)=='table' and value.kind or type(value) end
local function signal()
    local callbacks={}
    return {Connect=function(_,fn)
        callbacks[fn]=true
        return {kind='RBXScriptConnection',Disconnect=function() callbacks[fn]=nil end}
    end,fire=function(_,...) local copy={};for fn in pairs(callbacks) do copy[#copy+1]=fn end
        for _,fn in ipairs(copy) do if callbacks[fn] then fn(...) end end end}
end
local methods={}
local function node(class,name)
    local props={ClassName=class,Name=name or class,children={},attributes={},signals={},attributeSignals={},
        ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),AncestryChanged=signal()}
    local object={kind='Instance',props=props}
    return setmetatable(object,{__index=function(_,key) return methods[key] or props[key] end,
        __newindex=function(_,key,value)
            local previous=props[key];props[key]=value
            if previous==value then return end
            if key=='Parent' then
                if typeof(previous)=='Instance' then previous.ChildRemoved:fire(object) end
                if typeof(value)=='Instance' then
                    value.children[#value.children+1]=object;value.ChildAdded:fire(object)
                    local parent=value
                    while typeof(parent)=='Instance' do
                        parent.DescendantAdded:fire(object)
                        for _,child in ipairs(object:GetDescendants()) do parent.DescendantAdded:fire(child) end
                        parent=parent.Parent
                    end
                end
                object.AncestryChanged:fire(object,value)
            end
            if props.signals[key] then props.signals[key]:fire() end
        end})
end
function methods:IsA(class)
    return self.ClassName==class or class=='Instance'
        or (class=='BasePart' and (self.ClassName=='Part' or self.ClassName=='MeshPart'))
end
function methods:GetChildren() local list={};for _,child in ipairs(self.children) do if child.Parent==self then list[#list+1]=child end end;return list end
function methods:GetDescendants()
    local list={};local function visit(parent) for _,child in ipairs(parent:GetChildren()) do list[#list+1]=child;visit(child) end end
    visit(self);return list
end
function methods:FindFirstChild(name) for _,child in ipairs(self:GetChildren()) do if child.Name==name then return child end end end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self:GetChildren()) do if child:IsA(class) then return child end end end
function methods:GetPropertyChangedSignal(key) self.signals[key]=self.signals[key] or signal();return self.signals[key] end
function methods:GetAttributeChangedSignal(key) self.attributeSignals[key]=self.attributeSignals[key] or signal();return self.attributeSignals[key] end
function methods:SetAttribute(key,value)
    key=fixtureAttributes[key] or key
    local old=self.attributes[key];self.attributes[key]=value
    if old~=value and self.attributeSignals[key] then self.attributeSignals[key]:fire() end
end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:GetFullName()
    local value=self.Name;local parent=self.Parent
    while typeof(parent)=='Instance' do value=parent.Name..'.'..value;parent=parent.Parent end
    return value
end
function methods:Destroy() for _,child in ipairs(self:GetChildren()) do child:Destroy() end;self.Parent=nil end
local players,contentProvider
local game={GetService=function(_,name)
    if name=='Players' then return players end
    if name=='ContentProvider' then return contentProvider end
    error('Unexpected service '..name)
end}
local function actor(name,empty)
    local c=node('Model',name or 'Actor');c.Parent=true
    if not empty then
        local head=node('MeshPart','Head');head.MeshId='rbxassetid://6001';head.TextureID='rbxassetid://7001';head.Color='original-color';head.Parent=c
        local face=node('FaceControls');face.Parent=head
        local accessory=node('Accessory','OriginalHair');accessory.Parent=c
        local handle=node('MeshPart','Handle');handle.TextureID='rbxassetid://7003';handle.Parent=accessory
        c:SetAttribute('FunCombatHeadAssetId',12345);c:SetAttribute('FunCombatMoodAnimation',88);c:SetAttribute('FunCombatMoodClipId',89)
    end
    return c
end
local function fixture(empty)
    now=100;scheduled={}
    local p=node('Player','Owner');p.Parent=true;p.UserId=123;p.Character=actor('Actor',empty)
    p.CharacterAdded=signal();p.CharacterRemoving=signal()
    players={LocalPlayer=p,PlayerAdded=signal(),PlayerRemoving=signal()}
    function players:GetPlayers() return {p} end
    function players:GetPlayerFromCharacter(c) return p.Character==c and p or nil end
    local calls,reports,stateListeners,networkListeners={},{},{},{}
    contentProvider={PreloadAsync=function(_,content,callback)
        calls[#calls+1]={content=content,callback=callback}
    end}
    local ctx={config={Timeout=1},report=function(message) reports[#reports+1]=message end,
        state={onChanged=function(_,fn) stateListeners[fn]=true;return function() stateListeners[fn]=nil end end,
            all=function() return {} end},
        network={on=function(_,kind,fn) networkListeners[kind]=fn;return function() networkListeners[kind]=nil end end}}
    ctx.cleanup=cleanupFactory(ctx)
    local function state(c) for fn in pairs(stateListeners) do fn({character=c}) end end
    return ctx,p,p.Character,calls,reports,state,networkListeners
end
local function submitted(calls,want)
    for _,request in ipairs(calls) do for _,item in ipairs(request.content) do if item==want then return true end end end
    return false
end
local function message(reports,part)
    for _,value in ipairs(reports) do if value:find(part,1,true) then return value end end
end
'''
checks = r'''
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Avatar content: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
check('existing original head, accessory and genuine mood enter asynchronous preparation',function()
    local ctx,p,c,calls=fixture()
    local head=c:FindFirstChild('Head');local hair=c:FindFirstChild('OriginalHair'):FindFirstChild('Handle')
    local module=avatarContentFactory(ctx)
    assert(now==100,'Live avatar preparation blocked runtime initialization')
    advance(0.2)
    assert(submitted(calls,head),'The actual original head was never submitted')
    assert(submitted(calls,hair),'Original avatar accessories were never submitted')
    assert(submitted(calls,'rbxassetid://89'),'The genuine original facial mood was never submitted')
    assert(head.TextureID=='rbxassetid://7001' and head.Color=='original-color','Preparation changed avatar appearance')
    module:destroy();ctx.cleanup:destroy()
end)
check('late Head, hosted property changes and replicated mood are prepared once per change',function()
    local ctx,p,c,calls=fixture(true);local module=avatarContentFactory(ctx)
    advance(0.2);assert(#calls==0,'An absent head caused invented content requests')
    local head=node('MeshPart','Head');head.TextureID='rbxassetid://7010';head.Parent=c
    c:SetAttribute('FunCombatMoodAnimation',89);c:SetAttribute('FunCombatMoodClipId',90);advance(0.2)
    assert(submitted(calls,head) and submitted(calls,'rbxassetid://90'),'Late head or resolved mood was missed')
    local count=#calls
    head.TextureID='rbxassetid://7011';advance(0.2)
    assert(#calls==count+1,'A changed original head texture was never prepared')
    c.DescendantAdded:fire(head);advance(0.2)
    assert(#calls==count+1,'An unchanged head repeatedly downloaded')
    module:destroy();ctx.cleanup:destroy()
end)
check('head replacement, new accessory and respawn each prepare their actual references',function()
    local ctx,p,c,calls=fixture();local module=avatarContentFactory(ctx);advance(0.2)
    c:FindFirstChild('Head').Parent=nil
    local newHead=node('MeshPart','Head');newHead.TextureID='rbxassetid://7020';newHead.Parent=c
    local accessory=node('Accessory','LateHat');accessory.Parent=c
    local handle=node('MeshPart','Handle');handle.TextureID='rbxassetid://7021';handle.Parent=accessory
    advance(0.2);assert(submitted(calls,newHead) and submitted(calls,handle),'Replacement head or late accessory was missed')
    local replacement=actor('Respawn');p.Character=replacement;p.CharacterAdded:fire(replacement)
    advance(0.2);assert(submitted(calls,replacement:FindFirstChild('Head')),'Respawn head inherited a completed old request')
    module:destroy();ctx.cleanup:destroy()
end)
check('hosted failure reports its exact original asset ID and fetch status',function()
    local ctx,p,c,calls,reports=fixture()
    local original=contentProvider.PreloadAsync
    contentProvider.PreloadAsync=function(self,content,callback) original(self,content,callback);callback('rbxassetid://7001','Enum.AssetFetchStatus.Failure') end
    local module=avatarContentFactory(ctx);advance(0.2)
    local failure=message(reports,'rbxassetid://7001')
    assert(failure and failure:find('Failure',1,true),'Original head download failure had no asset/status diagnostic')
    module:destroy();ctx.cleanup:destroy()
end)
check('native content stall reports exact pending refs within its bounded deadline',function()
    local ctx,p,c,calls,reports=fixture()
    local original=contentProvider.PreloadAsync
    contentProvider.PreloadAsync=function(self,content,callback) original(self,content,callback);coroutine.yield() end
    local module=avatarContentFactory(ctx)
    assert(now==100,'A stalled native request blocked initialization')
    advance(1.3)
    local timeout=message(reports,'rbxassetid://7001')
    assert(timeout and timeout:lower():find('time',1,true),'Timed-out head content had no exact-reference diagnostic')
    assert(#calls==1,'A timed-out original head was retried indefinitely')
    module:destroy();ctx.cleanup:destroy()
end)
check('a timed-out native call does not multiply workers when current content changes',function()
    local ctx,p,c,calls=fixture()
    local original=contentProvider.PreloadAsync;local nativeThreads={}
    contentProvider.PreloadAsync=function(self,content,callback)
        original(self,content,callback);nativeThreads[#nativeThreads+1]=coroutine.running();coroutine.yield()
    end
    local module=avatarContentFactory(ctx);advance(1.3)
    c:FindFirstChild('Head').TextureID='rbxassetid://7050';advance(1.3)
    assert(#calls==1,'A stalled native preload accumulated parallel requests on every content change')
    assert(coroutine.resume(nativeThreads[1]));advance(0.2)
    assert(#calls==2,'Queued current content was lost when the original native request finally completed')
    module:destroy();ctx.cleanup:destroy()
end)
check('cancelled old-character callbacks cannot report after respawn or player removal',function()
    local ctx,p,c,calls,reports=fixture()
    local original=contentProvider.PreloadAsync
    contentProvider.PreloadAsync=function(self,content,callback) original(self,content,callback);coroutine.yield() end
    local module=avatarContentFactory(ctx);advance(0.2);assert(#calls==1,'Original request never began')
    local oldCallback=calls[1].callback
    local replacement=actor('Respawn');p.Character=replacement;p.CharacterAdded:fire(replacement);advance(0.2)
    oldCallback('rbxassetid://7001','Enum.AssetFetchStatus.Failure')
    assert(not message(reports,'Failure'),'A previous character produced a late failure')
    players.PlayerRemoving:fire(p);calls[#calls].callback('rbxassetid://7001','Enum.AssetFetchStatus.Failure')
    assert(not message(reports,'Failure'),'A removed player produced a late failure')
    module:destroy();advance(2);assert(not message(reports,'time'),'Cancelled observers produced timeout warnings')
    ctx.cleanup:destroy()
end)
check('late clients recover retained avatar warnings and keep unsupported PBR packs intact',function()
    local ctx,p,c,calls,reports=fixture()
    c:SetAttribute('FunCombatAvatarDiagnostic','Dynamic head asset 12345 could not load: access denied')
    local surface=node('SurfaceAppearance','OriginalPBR');surface.ColorMap='rbxassetid://7030';surface.NormalMap='rbxassetid://7031';surface.Parent=c:FindFirstChild('Head')
    local module=avatarContentFactory(ctx);advance(0.2)
    assert(message(reports,'12345') and message(reports,'access denied'),'A late client lost its retained original head warning')
    assert(not submitted(calls,surface),'PreloadAsync incorrectly certified an unsupported processed SurfaceAppearance pack')
    assert(surface.ColorMap=='rbxassetid://7030' and surface.NormalMap=='rbxassetid://7031' and surface.Parent==c:FindFirstChild('Head'),'Original PBR references were changed')
    assert(message(reports,'SurfaceAppearance'),'Unsupported PBR preload limitation was invisible')
    module:destroy();ctx.cleanup:destroy()
end)
check('state-fed user-ID dummies prepare their real heads and retire on Remove',function()
    local ctx,p,c,calls,reports,state,listeners=fixture(true);local module=avatarContentFactory(ctx)
    local dummy=actor('Rig');state(dummy);advance(0.2)
    assert(submitted(calls,dummy:FindFirstChild('Head')),'User-ID dummy content was excluded')
    assert(listeners.Remove,'Dummy lifecycle does not consume authoritative removal')
    listeners.Remove({character=dummy});local count=#calls
    dummy:FindFirstChild('Head').TextureID='rbxassetid://7040';advance(0.2)
    assert(#calls==count,'Removed dummy retained a live hosted-content watcher')
    module:destroy();ctx.cleanup:destroy()
end)
check('runtime cancellation suppresses pending content and retained warning work',function()
    local ctx,p,c,calls,reports=fixture();local module=avatarContentFactory(ctx)
    ctx.cancelled=true;advance(0.2)
    assert(#calls==0,'Cancelled runtime started a native avatar request')
    c:SetAttribute('FunCombatAvatarDiagnostic','late cancelled warning')
    assert(not message(reports,'late cancelled warning'),'Cancelled runtime reported stale character diagnostics')
    module:destroy();ctx.cleanup:destroy()
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Avatar content regression scenarios passed: '..total)
'''
path = ROOT / 'client/avatar_content.lua'
# An absent factory has the existing no-preparation behavior. This keeps RED
# assertions about missing requests rather than a Python file-read exception.
factory = path.read_text() if path.exists() else 'return function() return {destroy=function() end} end'
script = 'local fixtureAttributes='+lua(bindings.get('attributes',{}))+'\nlocal cleanupFactory, avatarContentFactory\n' + header
script += '\ncleanupFactory=(function()\n' + (ROOT / 'client/cleanup.lua').read_text() + '\nend)()\n'
script += '\navatarContentFactory=(function()\n' + factory + '\nend)()\n' + checks
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    test_path = Path(temporary) / 'avatar_content.luau'
    test_path.write_text(script)
    subprocess.run([str(Path(args.luau).resolve()), str(test_path)], check=True)
