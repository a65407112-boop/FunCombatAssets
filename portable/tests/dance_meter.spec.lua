local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local ok,install=pcall(dofile,'portable/dance_meter.lua');assert(ok,'The original meter GUI adapter must exist')
local count=0;local function check(v,why)assert(v,why);count=count+1 end
local now=0;tick=function()return now end
local Core=dofile('portable/core.lua');local core=Core.new({InteractDistance=6,DownDuration=18})
local a,v=core:register('a'),core:register('v');v.downed=true;v.ragdolled=true
local parent=Mock.object('Folder','PlayerGui');local mobile=Mock.object('ScreenGui','mobileButtons',parent);local r=Mock.object('TextButton','R',mobile)
local source=Mock.object('ScreenGui','meter');local frame=Mock.object('Frame','Frame',source);local container=Mock.object('Frame','container',frame)
local bar=Mock.object('Frame','bar',container);local percent=Mock.object('TextLabel','TextLabel',frame)
local label=Mock.object('TextLabel','TextLabel',source);local icon=Mock.object('ImageLabel','ImageLabel',label);local white=Mock.object('ImageLabel','white',source)
local current=a;local calls=0
local ctx={core=core,avatars={getLocal=function()return current end},catalog={packages={['gui/meter']={}}},guiParent=function()return parent end,
    assets={clone=function(_,key)assert(key=='gui/meter');return source:Clone()end},
    controller={advanceDance=function()calls=calls+1;return core:advanceDance(current,now)end},report=function(why)error(why)end}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);services.UserInputService.TouchEnabled=true
local meter=install(ctx,mobile);local gui=meter.gui
local actualFrame=gui:FindFirstChild('Frame');local actualBar=actualFrame:FindFirstChild('container'):FindFirstChild('bar')
local actualLabel=gui:FindFirstChild('TextLabel')
check(not gui.Enabled and not r.Visible,'Original meter and mobile R are hidden while idle')
assert(core:dance(a,v,0,1,4));assert(core:beginDanceMeter(a,0))
check(gui.Enabled and actualBar.Size.Y.Scale==0 and not actualLabel.Visible and not r.Visible,'Only the owner sees the active original meter')
now=10.4;core:tick(now)
check(actualBar.Size.Y.Scale==0.26 and actualLabel.Text=='R - Faster' and r.Visible,'The source threshold exposes keyboard/touch acceleration')
services.UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.R},true);check(calls==0,'Processed keyboard input is ignored')
services.UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.R},false)
check(calls==1 and core:danceMeterView(a).stage==2 and not r.Visible,'Keyboard R advances the actual owned state once')
now=15.84;core:tick(now);r.Activated:fire()
check(calls==2 and core:danceMeterView(a).stage==3,'Original mobile R advances the same action')
now=18.4;core:tick(now)
check(actualLabel.Text=='R - RELEASE'and actualLabel.Visible,'A full meter offers the original release label')
r.Activated:fire();check(calls==3 and not a.busy and not gui.Enabled and not r.Visible,'Release hides the meter and frees both records')
check(gui:FindFirstChild('white').Visible==false,'Meter actions never cover the screen with the source overlay')
v.downed=true;v.ragdolled=true;assert(core:dance(a,v,20,1,4));assert(core:beginDanceMeter(a,20));current=v;core:changed(v,'test')
check(not gui.Enabled and not r.Visible,'A target or replacement cannot inherit the initiator controls')
meter:destroy();services.UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.R},false);r.Activated:fire()
check(calls==3 and gui.Destroyed and not r.Visible,'Unload removes the owned GUI and both input callbacks')
ctx.cleanup:destroy();print('ORIGINAL DANCE METER TESTS '..count)
