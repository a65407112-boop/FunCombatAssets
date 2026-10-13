local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local ok,P=pcall(dofile,'portable/flight_probe.lua');assert(ok,'A separate flight diagnostic must distinguish real and proxy positions')
local world=Mock.object('Model','World');local source=Mock.object('Model','Real',world);local root=Mock.object('Part','HumanoidRootPart',source)
root.Position={X=0,Y=3,Z=0};root.AssemblyLinearVelocity={X=0,Y=0,Z=0}
local h=Mock.object('Humanoid','Humanoid',source);h.Health=100;h.GetState=function()return {Name='Running'}end
local folder=Mock.object('Folder','FunCombatPortable_Local',world);local proxy=Mock.object('Model','Proxy',folder)
local proxyRoot=Mock.object('Part','HumanoidRootPart',proxy);proxyRoot.Position={X=0,Y=3,Z=0};proxyRoot.CanCollide=false;proxyRoot.Anchored=true
local torso=Mock.object('Part','Torso',proxy);torso.Position={X=0,Y=30,Z=0};torso.CanCollide=false;torso.Anchored=true
local ph=Mock.object('Humanoid','Humanoid',proxy);ph.EvaluateStateMachine=false
local actor={character=proxy,avatar={model=proxy,parts={HumanoidRootPart=proxyRoot,Torso=torso},root=root},gender='Female'}
local player={Character=source,Name='Tester',UserId=1};local runtime={initialized=true,avatars={folder=folder,getLocal=function()return actor end},portableManifest={buildId='test'}}
local shot=P.capture(runtime,{player=player,workspace=world,clock=function()return 1 end})
assert(shot.source.root.position.y==3 and shot.proxy.torso.position.y==30,'Both real and drawn positions must be reported')
assert(shot.delta.proxyRootToSource==0 and shot.delta.torsoToSource==27,'Root and authored torso offset must be distinguished')
assert(shot.proxy.collidableParts==0 and root.CanCollide,'Real collision flags must remain unchanged')
torso.CanCollide=true;local hazard=P.capture(runtime,{player=player,workspace=world,clock=function()return 2 end})
assert(hazard.proxy.collidableParts==1 and hazard.proxy.collidingNames[1]=='Torso')
local summary=P.summary({shot,hazard});assert(summary.maxTorsoOffset==27 and summary.proxyCollisionObserved)
print('FLIGHT PROBE TESTS 5')
