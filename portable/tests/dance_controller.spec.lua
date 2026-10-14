local Mock=dofile('portable/tests/roblox_mock.lua')
local Core=dofile('portable/core.lua');local count=0
local function test(name,fn)fn();count=count+1;print('PASS dance controller: '..name)end
local vec={};vec.__index=vec;vec.__sub=function(a,b)return setmetatable({x=a.x-b.x,Magnitude=math.abs(a.x-b.x)},vec)end
local function position(x)return setmetatable({x=x},vec)end
local function setup()
    local services=Mock.install();local now=0;tick=function()return now end
    local core=Core.new({InteractDistance=6,DownDuration=18})
    local a,v=core:register('actor'),core:register('target');a.gender='Male';v.downed=true;v.ragdolled=true;v.recoverAt=20;v.displayName='Target'
    local world=Mock.object('Folder','World');a.character=Mock.object('Model','a',world);v.character=Mock.object('Model','v',world)
    local current=a;local pos={[a]=0,[v]=3};local events={}
    local ctx={core=core,config={DefaultWeapon='Bat'},catalog={packages={}},
        avatars={getLocal=function()return current end,distance=function()return 3 end,
            frame=function(_,r)return pos[r] and {Position=position(pos[r])}end,
            sourceFrame=function(_,r)return pos[r] and {Position=position(pos[r])}end},
        animations={preload=function(_,key)assert(key=='Emotes/Boston Breakdance');return {duration=4}end},
        network={emit=function(_,kind,data)events[#events+1]={kind=kind,data=data}end},state={get=function()return {}end},
        weapons={setTrails=function()end},status=function()end,report=function(why)error(why)end}
    ctx.cleanup=dofile('client/cleanup.lua')(ctx)
    local ctrl=dofile('portable/controller.lua')(ctx)
    assert(type(ctrl.pairedDance)=='function','Third action must start the ordinary original-emote dance')
    return ctx,ctrl,a,v,events,services,function(t)now=t end,function(r,x)pos[r]=x end,function(r)current=r end
end
test('both proxies play the same original ordinary emote at one start time',function()
    local ctx,ctrl,a,v,events=setup();assert(ctrl:pairedDance(v));assert(a.busy and v.busy)
    local clips={};for _,e in ipairs(events)do if e.kind=='Animation'then clips[#clips+1]=e.data end end
    assert(#clips==2 and clips[1].character==a.character and clips[2].character==v.character)
    assert(clips[1].key=='Emotes/Boston Breakdance' and clips[2].key==clips[1].key and clips[1].start==clips[2].start and clips[1].loop)
    ctx.cleanup:destroy()
end)
test('transitioning from an emote cannot stop the newly started dance',function()
    local ctx,ctrl,a,v,events,services=setup();assert(ctrl:emote('1'));assert(ctrl:pairedDance(v));local before=#events
    services.RunService.Heartbeat:fire(1/60);assert(#events==before and not ctrl.emoteRecord and a.dance)
    ctx.cleanup:destroy()
end)
test('moving either source participant cancels both proxy tracks',function()
    for _,who in ipairs({'actor','target'})do
        local ctx,ctrl,a,v,events,services,clock,move=setup();assert(ctrl:pairedDance(v));local before=#events
        move(who=='actor'and a or v,who=='actor'and 1 or 4);clock(1);services.RunService.Heartbeat:fire(1/60)
        assert(not a.dance and not v.dance and not a.busy and not v.busy)
        assert(#events==before+2 and events[#events].kind=='StopAnimation'and events[#events-1].kind=='StopAnimation')
        ctx.cleanup:destroy()
    end
end)
test('Stop and natural completion both release animations',function()
    for _,manual in ipairs({true,false})do
        local ctx,ctrl,a,v,events,services,clock=setup();assert(ctrl:pairedDance(v));local before=#events
        if manual then assert(ctrl:stopDance(v))else clock(61);services.RunService.Heartbeat:fire(1/60)end
        assert(not a.dance and not v.dance and #events==before+2 and a.kills==0 and v.health==100)
        ctx.cleanup:destroy()
    end
end)
test('speed changes keep both proxy animations on the same phase',function()
    local ctx,ctrl,a,v,events,services,clock=setup();assert(ctrl:pairedDance(v));clock(10.4)
    assert(ctrl:advanceDance());local first,second=events[#events-1].data,events[#events].data
    assert(first.character==a.character and second.character==v.character and first.speed==7 and second.speed==7 and first.start==second.start)
    assert(math.abs(((10.4-first.start)*first.speed)%4-(10.4%4))<1e-6,'Changing speed must not restart either copy at frame zero')
    ctrl:destroy();assert(not ctrl:advanceDance(),'An unloaded controller must reject acceleration')
    ctx.cleanup:destroy()
end)
test('character replacement departure and unload free the remaining participant',function()
    for _,kind in ipairs({'replacement','departure','unload'})do
        local ctx,ctrl,a,v,events,services,clock,move,select=setup();assert(ctrl:pairedDance(v))
        if kind=='replacement'then select(nil);services.RunService.Heartbeat:fire(1/60)
        elseif kind=='departure'then ctx.core:detach(v,1)
        else ctrl:destroy()end
        assert(not a.busy and not v.busy and not a.dance and not v.dance)
        ctx.cleanup:destroy()
    end
end)
test('unload still stops both animations when cleanup disposes connections first',function()
    local ctx,ctrl,a,v,events=setup();assert(ctrl:pairedDance(v));local before=#events
    -- Maid's unordered cleanup may disconnect the core callback before its final function.
    for token in pairs(ctx.core.listeners)do token:Disconnect()end
    ctrl:destroy()
    assert(not a.busy and not v.busy and #events==before+2 and events[#events].kind=='StopAnimation'and events[#events-1].kind=='StopAnimation',
        'Controller unload must stop both owned tracks even after its state listener has disconnected')
    ctx.cleanup:destroy()
end)
test('failed clip load gives a specific error without reserving targets',function()
    local ctx,ctrl,a,v,events=setup();ctx.animations.preload=function()error('ordinary emote fetch failed')end
    local ok,why=ctrl:pairedDance(v);assert(not ok and why:find('ordinary emote fetch failed')and not a.busy and not v.busy and #events==0)
    ctx.cleanup:destroy()
end)
test('a respawn during a yielding preload cannot animate a stale actor',function()
    local ctx,ctrl,a,v,events,services,clock,move,select=setup()
    ctx.animations.preload=function()coroutine.yield();return {duration=4}end
    local thread=coroutine.create(function()assert(not ctrl:pairedDance(v))end);assert(coroutine.resume(thread))
    ctx.core:detach(a,0);local fresh=ctx.core:register('fresh');fresh.gender='Male';select(fresh)
    assert(coroutine.resume(thread));assert(not fresh.busy and not v.busy and not v.dance and #events==1)
    ctx.cleanup:destroy()
end)
test('preload cannot resume or start through an unloaded controller',function()
    local ctx,ctrl,a,v,events=setup()
    ctx.animations.preload=function()coroutine.yield();return {duration=4}end
    local result
    local thread=coroutine.create(function()result=ctrl:pairedDance(v)end);assert(coroutine.resume(thread))
    ctrl:destroy();assert(coroutine.resume(thread))
    assert(result==false and not a.busy and not v.busy and #events==0,'Unloading during preload must cancel the pending dance')
    ctx.animations.preload=function()error('An unloaded controller must not fetch resources')end
    assert(not ctrl:pairedDance(v),'An unloaded controller must reject new dance requests')
    ctx.cleanup:destroy()
end)
print('PAIRED DANCE CONTROLLER TESTS '..count)
