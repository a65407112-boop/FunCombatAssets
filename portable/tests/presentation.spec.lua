local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
Vector3={new=function(x,y,z)return {X=x or 0,Y=y or 0,Z=z or 0}end}
workspace=Mock.object('Model','Workspace');workspace.DescendantAdded=Mock.signal();workspace.Gravity=196.2
services.Players={LocalPlayer={},GetPlayers=function()return {}end,PlayerAdded=Mock.signal(),PlayerRemoving=Mock.signal()}
local ctx={modules={appearance=dofile('portable/appearance.lua'),visibility=dofile('portable/visibility.lua')},config={Timeout=15},
    animations={stop=function()end},core={records={}},report=function(e)error(e)end}
local ok,R=pcall(dofile,'portable/ragdoll.lua');if ok then ctx.modules.ragdoll=R end
ctx.cleanup=dofile('client/cleanup.lua')(ctx)
local avatars=dofile('portable/avatars.lua')(ctx)
local model=Mock.object('Model','Proxy',avatars.folder);local root=Mock.object('Part','HumanoidRootPart',model);local torso=Mock.object('Part','Torso',model)
local frame={Position={X=0,Y=3,Z=0},ToOrientation=function()return 0,0,0 end};root.CFrame=frame;torso.CFrame=frame
for _,p in ipairs({root,torso})do p.Anchored=true;p.CanCollide=false end
local record={};local e={model=model,root=root,parts={HumanoidRootPart=root,Torso=torso},motors={},accessories={},scope=ctx.cleanup:scope(),record=record};record.avatar=e
avatars:setRagdoll(e,true)
for _,p in pairs(e.parts)do assert(p.Anchored and not p.CanCollide,'Ragdoll must never turn a proxy into an unanchored collidable assembly')end
assert(#model:GetDescendants()==2,'Visual ragdoll must not create physics joints or forces')
avatars:setRagdoll(e,false);for _,p in pairs(e.parts)do assert(p.Anchored and not p.CanCollide)end
print('RAGDOLL ISOLATION TESTS 3')
