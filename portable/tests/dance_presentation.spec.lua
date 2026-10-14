local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
Vector3={new=function(x,y,z)return {X=x or 0,Y=y or 0,Z=z or 0}end}
workspace=Mock.object('Model','Workspace');workspace.DescendantAdded=Mock.signal()
services.Players={LocalPlayer={},GetPlayers=function()return {}end,PlayerAdded=Mock.signal(),PlayerRemoving=Mock.signal()}
local ctx={modules={appearance=dofile('portable/appearance.lua'),visibility=dofile('portable/visibility.lua'),ragdoll=dofile('portable/ragdoll.lua')},
    config={Timeout=15},core={records={}},report=function(why)error(why)end}
ctx.cleanup=dofile('client/cleanup.lua')(ctx)
local avatars=dofile('portable/avatars.lua')(ctx)
local function entry(name,x)
    local source=Mock.object('Model',name,workspace);local root=Mock.object('Part','HumanoidRootPart',source);root.CFrame=Mock.cf(x)
    local proxy=Mock.object('Model',name..'Copy',avatars.folder);local torso=Mock.object('Part','Torso',proxy);torso.CFrame=Mock.cf(x)
    local r={};r.avatar={model=proxy,root=root,parts={Torso=torso}};return r,root
end
local a,aroot=entry('actor',10);local v,vroot=entry('target',14)
local originalA,originalV=aroot.CFrame,vroot.CFrame;local link={a=a,v=v};a.dance=link;v.dance=link
assert(avatars:frame(v).value==13,'Dance places only the target proxy beside the actor instead of overlapping both roots')
assert(avatars:sourceFrame(v)==originalV and avatars:sourceFrame(a)==originalA,'Movement checks read actual source roots, not arranged proxy frames')
assert(aroot.CFrame==originalA and vroot.CFrame==originalV and not aroot.Anchored and not vroot.Anchored,'Dance placement must not teleport or anchor real participants')
v.dance=nil;assert(avatars:frame(v)==originalV,'Ending the arrangement restores normal source following')
ctx.cleanup:destroy()
print('PAIRED DANCE PRESENTATION TESTS 4')
