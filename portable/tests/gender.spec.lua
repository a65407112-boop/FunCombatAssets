local Mock=dofile('portable/tests/roblox_mock.lua');Mock.install()
local Core=dofile('portable/core.lua');local core=Core.new({})
local a=core:register('a');a.character=Mock.object('Model','Proxy',Mock.object('Folder','World'))
local avatar=a;local ctx={core=core,config={DefaultWeapon='Bat'},catalog={packages={['weapons/Bat']={}}},
    avatars={getLocal=function()return avatar end},assets={clone=function()return Mock.object('Tool','Bat')end},
    network={emit=function()end},state={get=function()return {}end},status=function()end,report=function(e)error(e)end,weapons={setTrails=function()end}}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);local controller=dofile('portable/controller.lua')(ctx)
assert(not controller:equip('Bat'),'Equipping must wait for the original gender selection')
assert(controller:selectGender('Female'));assert(a.gender=='Female' and ctx.gender=='Female' and a.weapon=='Bat')
assert(not controller:selectGender('unknown'));assert(a.gender=='Female','Invalid choice must preserve the previous selection')
core:detach(a,0);avatar=core:register('respawn');avatar.character=Mock.object('Model','Proxy2',Mock.object('Folder','World'))
core:changed(avatar,'ready');assert(avatar.gender=='Female' and avatar.weapon=='Bat','Gender and weapon choice must survive respawn')
controller:destroy();avatar.weapon='';avatar.gender='Female'
local resumed=dofile('portable/controller.lua')(ctx)
assert(avatar.weapon=='Bat','An already-mounted avatar must equip when the controller is created after its ready event')
print('GENDER FLOW TESTS 5')
