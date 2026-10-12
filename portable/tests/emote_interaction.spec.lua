local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local Core=dofile('portable/core.lua');local core=Core.new({InteractDistance=6,DownDuration=18})
local parent=Mock.object('Folder','World');local a,v=core:register('a'),core:register('v')
a.character=Mock.object('Model','a',parent);v.character=Mock.object('Model','v',parent);a.gender='Male';v.downed=true
v.displayName='Target'
local lastPose
local ctx={config={DefaultWeapon='Bat'},core=core,catalog={packages={}},avatars={getLocal=function()return a end,frame=function()return {}end,distance=function()return 1 end},
    state={get=function()return {}end},network={emit=function(_,kind,data)if data.character==a.character and (kind=='Animation'or kind=='StopAnimation')then lastPose={kind=kind,key=data.key}end end},
    weapons={setTrails=function()end},status=function()end,report=function(e)error(e)end}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);local controller=dofile('portable/controller.lua')(ctx)
assert(controller:emote('1'));assert(controller:carry(v));services.RunService.Heartbeat:fire(1/60)
assert(lastPose.kind=='Animation'and lastPose.key=='other/carryGrabber','Ending an emote must not stop the new carry animation')
print('EMOTE TRANSITION TESTS 1')
