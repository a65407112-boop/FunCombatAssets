local Mock=dofile('portable/tests/roblox_mock.lua');Mock.install()
local ok,P=pcall(dofile,'portable/passive.lua');assert(ok,'Proxy simulation disabling must be verified instead of ignored')
local ctx={report=function(e)error(e)end};ctx.cleanup=dofile('client/cleanup.lua')(ctx)
local model=Mock.object('Model','Proxy');model.DescendantAdded=Mock.signal();model.DescendantRemoving=Mock.signal()
local hum=Mock.object('Humanoid','Humanoid',model);hum.EvaluateStateMachine=true
local part=Mock.object('Part','Torso',model);local source=Mock.object('Part','RealRoot');source.Anchored=false;source.CanCollide=true
local faults={};local guard=P.install(model,hum,ctx.cleanup,function(e)faults[#faults+1]=e end)
assert(hum.EvaluateStateMachine==false and part.Anchored and not part.CanCollide)
part.CanCollide=true;part:GetPropertyChangedSignal('CanCollide'):fire();assert(not part.CanCollide,'Reenabled collision must be repaired')
part.Anchored=false;part:GetPropertyChangedSignal('Anchored'):fire();assert(part.Anchored,'Proxy parts must remain anchored')
hum.EvaluateStateMachine=true;hum:GetPropertyChangedSignal('EvaluateStateMachine'):fire();assert(hum.EvaluateStateMachine==false)
assert(source.CanCollide and not source.Anchored,'Passivity enforcement must never touch the real root')
local departed=Mock.object('Part','OldWeapon',model);model.DescendantAdded:fire(departed)
model.DescendantRemoving:fire(departed);departed.Parent=nil
assert(guard.parts[departed]==nil,'Replaced weapon parts must leave the pre-simulation scan')
departed.Anchored=false;departed:GetPropertyChangedSignal('Anchored'):fire()
assert(not departed.Anchored,'Removed weapon parts must lose their repair callbacks')
local unsupported=Mock.object('Humanoid','Unsupported');unsupported.EvaluateStateMachine=true
local mt=getmetatable(unsupported);local write=mt.__newindex;mt.__newindex=function(t,k,v)if k=='EvaluateStateMachine'then error('Property unsupported')end;write(t,k,v)end
local success,why=P.prepareHumanoid(unsupported);assert(not success and tostring(why):find('simulation'),'Unsupported simulation disabling must fail explicitly')
local denied=getmetatable(part);local writePart=denied.__newindex;denied.__newindex=function(t,k,v)if k=='CanCollide'and v==false then error('denied')end;writePart(t,k,v)end
part.CanCollide=true;part:GetPropertyChangedSignal('CanCollide'):fire();assert(#faults==1,'A refused collision repair must remove the unsafe proxy through its owner')
print('PASSIVE PROXY TESTS 9')
