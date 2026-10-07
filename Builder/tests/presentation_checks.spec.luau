local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print("Presentation: "..name) else failures[#failures+1]=name..": "..tostring(why);print("FAIL "..failures[#failures]) end
end
check("upper-body attacks, equip and carry preserve gait",function()
    local ctx=context();local animations=animationsFactory(ctx);local c=character()
    for _,key in ipairs({"bat/swing_1","bat/swing_2","bat/flourish","bat/unequip","other/carryGrabber"}) do
        animations:play({character=c,key=key,start=now})
        assert(not animations:blocksLocomotion(c),key.." stopped unowned leg joints")
    end
    ctx.cleanup:destroy()
end)
check("authored third swing and carried victim retain full-body poses",function()
    local ctx=context();local animations=animationsFactory(ctx);local c=character()
    for _,key in ipairs({"bat/swing_3","other/carryGrabbed"}) do
        animations:play({character=c,key=key,start=now})
        assert(animations:blocksLocomotion(c),key.." lost its authored leg poses")
    end
    ctx.cleanup:destroy()
end)
check("combat pose wins after Animator without touching a walking hip",function()
    local ctx=context();local animations=animationsFactory(ctx);local c,_,arm,hip=character()
    animations:play({character=c,key="bat/swing_1",start=now})
    run.Stepped:fire();arm.Transform=frame(99,0,0);hip.Transform=frame(42,0,0)
    now=100.5;run.PreSimulation:fire()
    assert(arm.Transform[1]==7,"Animator overwrote the combat pose")
    assert(hip.Transform[1]==42,"An upper-body clip overwrote the walking hip")
    ctx.cleanup:destroy()
end)
check("legacy clients use the bounded Stepped fallback",function()
    local ctx=context(true);local animations=animationsFactory(ctx);local c,_,arm=character()
    animations:play({character=c,key="bat/swing_1",start=now});now=100.5;run.Stepped:fire()
    assert(arm.Transform[1]==7,"Legacy frame event did not play the original pose")
    ctx.cleanup:destroy()
end)
check("R6 attachment grip retains the native quarter-turn and original Tool.Grip",function()
    local ctx=context();local c,arm=character();local attachment=node("Attachment","RightGripAttachment")
    attachment.CFrame=frame(0,-1,0);attachment.Parent=arm
    local grip=frame(0,0,-1.5,0,0,1,1,0,0,0,1,0)
    local function weapon()
        local tool=node("Tool","Bat");tool.Grip=grip
        local handle=node("Part","Handle");handle.Parent=tool
        return tool
    end
    ctx.assets={clone=function(_,key) assert(key=="weapons/Bat");return weapon() end}
    local weapons=weaponsFactory(ctx);weapons:update({character=c,weapon="Bat"})
    local motor=assert(arm:FindFirstChild("RightGrip"))
    sameFrame(motor.C0,{0,-1,0,1,0,0,0,0,1,0,-1,0})
    sameFrame(motor.C1,{0,0,-1.5,0,0,1,1,0,0,0,1,0})
    weapons:destroy();assert(not motor.Parent,"Grip survived runtime cleanup")
    ctx.cleanup:destroy()
end)
check("warm resources serve a first action without another fetch",function()
    local ctx,reads=context();ctx.assets=assetsFactory(ctx);ctx.animations=animationsFactory(ctx)
    assert(type(preloadFactory)=="function","Resource warm-up is missing")
    preloadFactory(ctx)
    for key,entry in pairs(ctx.catalog.animations) do assert(reads[entry.path]==1,"Animation was not warmed: "..key) end
    assert(reads["asset/equip"]==1,"Sound package was not warmed")
    -- The slow external dependency now becomes unavailable. A first action must
    -- use the warmed production caches rather than retrying a download.
    function ctx.json(path) error("Late download during gameplay: "..path) end
    local c=character();ctx.animations:play({character=c,key="bat/swing_1",start=now})
    assert(ctx.animations:isPlaying(c),"First swing still depended on a download")
    local sound=ctx.assets:clone("audio/Equip");assert(sound.SoundId=="fixture-original-sound")
    sound:Destroy();ctx.cleanup:destroy()
end)
check("cancelled warm-up cannot make the runtime ready",function()
    local ctx=context();ctx.assets=assetsFactory(ctx);ctx.animations=animationsFactory(ctx);ctx.cancelled=true
    assert(type(preloadFactory)=="function","Resource warm-up is missing")
    assert(not pcall(preloadFactory,ctx),"Cancelled initialization continued")
    ctx.cleanup:destroy()
end)
check("missing original model backend fails before gameplay becomes ready",function()
    local ctx=context();ctx.assets=assetsFactory(ctx);ctx.animations=animationsFactory(ctx)
    ctx.catalog.packages["costumes/TorsoRig"]={backend="model"}
    local clone=ctx.assets.clone
    function ctx.assets:clone(key)
        if key=="costumes/TorsoRig" then error("Original-model deserializer unavailable") end
        return clone(self,key)
    end
    local ok,why=pcall(preloadFactory,ctx)
    assert(not ok and tostring(why):find("costumes/TorsoRig"),"Missing original TorsoRig was silently skipped")
    ctx.cleanup:destroy()
end)
check("hosted content timeout names the actual resource and status",function()
    local ctx,_,reports=context();ctx.assets=assetsFactory(ctx);ctx.animations=animationsFactory(ctx)
    contentProvider.PreloadAsync=function(_,_,callback) callback("fixture-original-gait","Enum.AssetFetchStatus.TimedOut") end
    preloadFactory(ctx)
    local found=false;for _,message in ipairs(reports) do if message:find("fixture%-original%-gait") and message:find("TimedOut") then found=true end end
    assert(found,"Hosted preload silently accepted a timed-out resource")
    ctx.cleanup:destroy()
end)
check("stalled warm-up exits at its deadline and late fetches cannot leak assets",function()
    local ctx=context();ctx.assets=assetsFactory(ctx);ctx.animations=animationsFactory(ctx)
    local read,pending=ctx.json,{}
    function ctx.json(path) pending[#pending+1]=coroutine.running();coroutine.yield();return read(path) end
    local ok,why=pcall(preloadFactory,ctx)
    assert(not ok and tostring(why):find("deadline") and now<=110.1,"Stalled resources caused an unbounded bootstrap wait")
    ctx.cancelled=true;ctx.cleanup:destroy()
    for _,thread in ipairs(pending) do assert(coroutine.resume(thread)) end
    assert(next(ctx.assets.cache)==nil,"A cancelled late fetch installed original assets into the destroyed runtime")
end)
check("remote observer preserves the already replicated owner gait without a duplicate",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,hum,tracks=walkingFigure(ctx,false)
    c:SetAttribute('FunCombatMoodAnimation',0);players.LocalPlayer.Character=nil;players.characters[c]={Name='OtherPlayer'}
    local animation=node('Animation','OwnerWalk');animation.AnimationId='fixture-original-gait'
    local native=hum:LoadAnimation(animation);native:Play();native:AdjustSpeed(1.37);native.TimePosition=0.42
    local characters=charactersFactory(ctx);run.Heartbeat:fire(0.016)
    local count=0;for _,t in ipairs(hum:GetPlayingAnimationTracks()) do if t.Animation.AnimationId=='fixture-original-gait' then count+=1 end end
    assert(not native.stopped and count==1 and native.speed==1.37 and native.TimePosition==0.42,
        'Observer stopped, duplicated or retimed the owner gait')
    characters:destroy();assert(not native.stopped and not native.destroyed,'Observer cleanup destroyed a track owned by the other player')
    ctx.cleanup:destroy()
end)
check("late replicated gait replaces only the observer fallback",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,hum,tracks=walkingFigure(ctx,false)
    c:SetAttribute('FunCombatMoodAnimation',0);players.LocalPlayer.Character=nil;players.characters[c]={Name='OtherPlayer'}
    local characters=charactersFactory(ctx);run.Heartbeat:fire(0.016);local fallback=assert(tracks[1])
    local animation=node('Animation','OwnerWalk');animation.AnimationId='fixture-original-gait'
    local native=hum:LoadAnimation(animation);native:Play();native.TimePosition=0.75
    run.Heartbeat:fire(0.016)
    assert(fallback.stopped and not native.stopped and native.TimePosition==0.75,'Late replication left two competing gait tracks')
    characters:destroy();assert(not native.stopped,'Late owner track was mistaken for an owned fallback')
    ctx.cleanup:destroy()
end)
check("remote native jump is not replaced by an observer walk estimate",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,hum,tracks=walkingFigure(ctx,false)
    c:SetAttribute('FunCombatMoodAnimation',0);players.LocalPlayer.Character=nil;players.characters[c]={Name='OtherPlayer'}
    ctx.json('assets/animations/locomotion.json')['jump/JumpAnim']={Name='JumpAnim',AnimationId='rbxassetid://125750702'}
    local animation=node('Animation','OwnerJump');animation.AnimationId='http://www.roblox.com/asset/?id=125750702'
    local native=hum:LoadAnimation(animation);native:Play()
    local characters=charactersFactory(ctx);run.Heartbeat:fire(0.016)
    local count=0;for _,t in ipairs(hum:GetPlayingAnimationTracks()) do count+=1 end
    assert(not native.stopped and count==1,'Remote velocity estimate overwrote the owner jump')
    characters:destroy();ctx.cleanup:destroy()
end)
check("remote lean uses visible horizontal movement while MoveDirection is zero",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,hum=walkingFigure(ctx,false)
    c:SetAttribute('FunCombatMoodAnimation',0);players.LocalPlayer.Character=nil;players.characters[c]={Name='OtherPlayer'}
    local root=c:FindFirstChild('HumanoidRootPart');local joint=node('Motor6D','RootJoint');joint.C0=frame();joint.Parent=root
    local characters=charactersFactory(ctx);run.Heartbeat:fire(1/7)
    assert(math.abs(joint.C0[6]-math.sin(-0.13))<0.00001,'Remote lean incorrectly used unreplicated MoveDirection')
    root.Velocity=Vector3.new();run.Heartbeat:fire(1/7);sameFrame(joint.C0,frame())
    characters:destroy();ctx.cleanup:destroy()
end)
check("local lean retains original input direction rather than a remote velocity estimate",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,hum=walkingFigure(ctx,false)
    c:SetAttribute('FunCombatMoodAnimation',0);hum.MoveDirection=Vector3.new(0,0,-1)
    local root=c:FindFirstChild('HumanoidRootPart');local joint=node('Motor6D','RootJoint');joint.C0=frame();joint.Parent=root
    local characters=charactersFactory(ctx);run.Heartbeat:fire(1/7)
    assert(math.abs(joint.C0[9]+math.sin(0.065))<0.00001,'Local authored lean changed to the root velocity direction')
    characters:destroy();ctx.cleanup:destroy()
end)
check("original facial mood loads and continues under a full-body combat lock",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local c,_,tracks=walkingFigure(ctx,false)
    local characters=charactersFactory(ctx);run.Heartbeat:fire(0.016)
    local mood,gait
    for _,track in ipairs(tracks) do
        if track.Animation.AnimationId=="rbxassetid://88" then mood=track end
        if track.Animation.AnimationId=="fixture-original-gait" then gait=track end
    end
    assert(mood and mood.played and mood.Looped,"Original facial mood was never restored after disabling Animate")
    assert(gait and gait.played,"The original walking gait is missing")
    ctx.animations:play({character=c,key="bat/swing_3",start=now});run.Heartbeat:fire(0.016)
    assert(gait.stopped and not mood.stopped,"Full-body combat stopped the facial mood together with gait")
    characters:destroy();assert(mood.stopped,"An owned facial mood leaked after repeated loader cleanup")
    ctx.cleanup:destroy()
end)
check("an already playing original facial mood is preserved without a duplicate",function()
    local ctx=context();ctx.animations=animationsFactory(ctx);local _,_,tracks=walkingFigure(ctx,true)
    local original=tracks[1];local characters=charactersFactory(ctx);run.Heartbeat:fire(0.016)
    local count=0;for _,track in ipairs(tracks) do if track.Animation.AnimationId=="rbxassetid://88" then count+=1 end end
    assert(not original.stopped and count==1,"Native facial mood was stopped or duplicated")
    characters:destroy();assert(not original.stopped,"Runtime cleanup destroyed an engine-owned facial mood")
    ctx.cleanup:destroy()
end)
assert(#failures==0,table.concat(failures,"\n"))
print("Presentation regression scenarios passed: "..total)
