local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local now=0;tick=function()return now end
local vec={};vec.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)elseif k=='Unit'then local m=math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z);return Vector3.new(t.X/m,t.Y/m,t.Z/m)end;return vec[k]end
vec.__mul=function(a,n)return Vector3.new(a.X*n,a.Y*n,a.Z*n)end
Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vec)end}
local ok,D=pcall(dofile,'portable/dash.lua');assert(ok,'The original horizontal dash must be available')
local world=Mock.object('Folder','World');local real=Mock.object('Model','Real',world);local root=Mock.object('Part','HumanoidRootPart',real)
root.Anchored=false;root.CFrame={LookVector=Vector3.new(0,0,-1),Position=Vector3.new()};local originalFrame=root.CFrame
local hum=Mock.object('Humanoid','Humanoid',real);hum.Health=100;hum.MoveDirection=Vector3.new(1,9,0)
local actor={alive=true,weapon='Bat',avatar={root=root,humanoid=hum},character=Mock.object('Model','Proxy',world)}
local current=actor;local ctx={config={},core={valid=function(_,r)return r.alive end,free=function(_,r)return r.alive and not r.busy end,changed=function()end},
    avatars={getLocal=function()return current end},report=function(e)error(e)end,network={emit=function()end},dashBlocked=function()return false end}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);local dash=D(ctx)
assert(dash:start(actor,now));assert(not dash:start(actor,now),'Duplicate dash must obey original cooldown')
now=0.14;dash:step(now);assert(not root:FindFirstChild('FunCombatPortable_Dash'),'Dash must honor original startup')
now=0.15;dash:step(now);local force=assert(root:FindFirstChild('FunCombatPortable_Dash'))
assert(force.MaxForce.Y==0 and force.Velocity.Y==0 and math.abs(force.Velocity.X-60)<0.01,'Original dash must apply only horizontal force')
assert(root.CFrame==originalFrame,'Dash must not teleport or rewrite the root CFrame')
now=0.46;dash:step(now);assert(force.Destroyed and not root:FindFirstChild('FunCombatPortable_Dash'),'Dash force must expire after 0.3 seconds')
now=2;assert(dash:start(actor,now));now=2.16;dash:step(now);local interrupted=assert(root:FindFirstChild('FunCombatPortable_Dash'))
actor.busy=true;dash:step(now);assert(interrupted.Destroyed,'Starting an interaction must stop dash')
actor.busy=false;now=4;assert(dash:start(actor,now));current=nil;dash:step(4.2);assert(not root:FindFirstChild('FunCombatPortable_Dash'),'Respawn/removal must cancel a pending dash')
current=actor;now=6;assert(dash:start(actor,now));dash:step(6.2);ctx.cleanup:destroy();assert(not root:FindFirstChild('FunCombatPortable_Dash'),'Unload must remove its force')
print('HORIZONTAL DASH TESTS 9')
