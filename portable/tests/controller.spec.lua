unpack=table.unpack
local clock=0;tick=function()return clock end
local connection={Disconnect=function()end}
game={GetService=function()return {Heartbeat={Connect=function()return connection end}}end}
local scope={add=function(_,x)return x end,destroy=function()end}
local cleanup={scope=function()return scope end,dead=false}
local Core=dofile('portable/core.lua')
local core=Core.new({Damage={17,17,35},SwingCooldown={0.4,0.4,1},Startup={0.1,0.1,0.2},ActiveWindow=0.2,DownDuration=12,InteractDistance=6})
local a,v=core:register('a'),core:register('v');a.character={Parent=true};v.character={Parent=true};a.weapon='Bat';v.downed=true
a.gender='Male'
local loadingCoroutine
local ctx={cleanup=cleanup,core=core,config={DefaultWeapon='Bat'},catalog={packages={['weapons/Sword']={},['weapons/Bat']={}}},
    avatars={getLocal=function()return a end},assets={clone=function()loadingCoroutine=coroutine.running();coroutine.yield();return {Destroy=function()end}end},
    status=function()end,report=function(e)error(e)end,network={emit=function()end},weapons={setTrails=function()end,get=function()return {}end},state={get=function()return {}end}}
local ctrl=dofile('portable/controller.lua')(ctx)
assert(ctrl:equip('Sword'));assert(ctrl.loading)
assert(core:carry(a,v,0,1));assert(not ctrl:equip('Bat'))
assert(coroutine.resume(loadingCoroutine));assert(not ctrl.loading,'Rejected equip during Carry must not leave loading permanently true')
assert(core:drop(a,0.2));clock=1;assert(ctrl:swing(),'Attack must recover after dropping with an interrupted weapon load')
print('CONTROLLER RACE TESTS 2')
