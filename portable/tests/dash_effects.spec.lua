local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local now=0;tick=function()return now end
local ok,Factory=pcall(dofile,'portable/dash_effects.lua');assert(ok,'Original dash visuals need a portable receiver')
local world=Mock.object('Folder','World');local proxy=Mock.object('Model','Proxy',world)
for _,name in ipairs({'HumanoidRootPart','Left Arm','Right Arm','Left Leg','Right Leg'})do Mock.object('Part',name,proxy)end
local real=Mock.object('Part','RealRoot',world);local realCollide=real.CanCollide
local created,keys={},{}
local ctx={report=function(e)error(e)end,avatars={byModel={[proxy]={}}},assets={clone=function(_,key)
    keys[key]=(keys[key]or 0)+1
    local root=Mock.object('Part','OriginalEffect');created[#created+1]=root
    local a=Mock.object('Attachment','A',root);local b=Mock.object('Attachment','B',root)
    local trail=Mock.object('Trail','Trail',root);trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=0.4
    local particle=Mock.object('ParticleEmitter','Dust',a);particle.Lifetime={Max=0.5}
    root.trail=trail;root.particle=particle;return root
end}}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);ctx.network=dofile('portable/bus.lua').new(tick,ctx.report)
local fx=Factory(ctx)
ctx.network:emit('Effect',{character=proxy,key='effects/dash_limbs',duration=0.3})
assert(keys['effects/dash_limbs']==4,'Dash must restore the four original limb effects')
for _,c in ipairs(created)do
    assert(c.Parent==nil and c.trail.Parent==c.trail.Attachment0.Parent and c.trail.Parent==c.trail.Attachment1.Parent,'Clone children must retain original Trail attachment references without parenting source parts')
end
ctx.network:emit('Effect',{character=proxy,key='effects/dash_smoke',duration=0.3})
assert(keys['effects/dash_smoke']==1 and created[5].trail.Parent==proxy:FindFirstChild('HumanoidRootPart'),'Ground decision belongs to the source character, not the disabled proxy Humanoid')
now=0.31;services.RunService.Heartbeat:fire()
for _,c in ipairs(created)do assert(c.trail.Enabled==false and c.particle.Enabled==false and not c.trail.Destroyed,'Emitters stop but particle/trail tails can finish')end
now=2.5;services.RunService.Heartbeat:fire()
for _,c in ipairs(created)do assert(c.Destroyed and c.trail.Destroyed,'Original effect children must be disposed after their tail')end
ctx.network:emit('Effect',{character=proxy,key='effects/dash_smoke',duration=0.3});local removed=created[#created]
ctx.network:emit('Remove',{character=proxy});assert(removed.trail.Destroyed,'Respawn/removal must dispose dash visuals')
ctx.network:emit('Effect',{character=proxy,key='effects/dash_smoke',duration=0.3});local last=created[#created]
ctx.cleanup:destroy();assert(last.trail.Destroyed and real.CanCollide==realCollide,'Unload must dispose only owned effects')
print('ORIGINAL DASH EFFECT TESTS 7')
