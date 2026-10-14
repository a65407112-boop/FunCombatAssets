return function(ctx)
    local Run=game:GetService("RunService")
    local scope=ctx.cleanup:scope()
    local module={selected=ctx.weaponChoice or ctx.config.DefaultWeapon,equipTicket=0,active=nil}
    local genders={Female=true,Male=true,Fembxy=true}
    local emotes={['1']='Emotes/Boston Breakdance',['2']='Emotes/Flex',['3']='Emotes/Rat',['4']='Emotes/Akiyama',['5']='Emotes/idk'}
    local function state(r)return ctx.state:get(r.character)end
    local function sound(r,key)
        if r and r.character and r.character.Parent then ctx.network:emit("Sound",{character=r.character,key=key})end
    end
    local function animation(r,key,loop,start)
        if not r or not r.character then return end
        r.revision=r.revision+1
        ctx.network:emit("Animation",{character=r.character,key=key,start=start or tick(),revision=r.revision,loop=loop})
    end
    local function stop(r)
        if not r or not r.character then return end
        r.revision=r.revision+1;ctx.network:emit("StopAnimation",{character=r.character,revision=r.revision})
        ctx.weapons:setTrails(r.character,false)
    end
    local function sourceFrame(r)
        if ctx.avatars.sourceFrame then return ctx.avatars:sourceFrame(r)end
        return ctx.avatars:frame(r)
    end
    function module:equip(name)
        if not ctx.catalog.packages["weapons/"..tostring(name)] then return false,"Unknown original weapon"end
        local r=ctx.avatars:getLocal()
        if not r or not genders[r.gender]then return false,"Choose your gender first"end
        if not ctx.core:free(r)then return false,"Your local avatar must be ready and free"end
        self.equipTicket=self.equipTicket+1;local ticket=self.equipTicket
        self.loading=true;ctx.status("Loading "..name.."...")
        coroutine.wrap(function()
            local ok,result=pcall(function()return ctx.assets:clone("weapons/"..name)end)
            if ok then result:Destroy()end
            if ok and ctx.dash then
                ok,result=pcall(function()
                    for _,soundName in ipairs({"DashSound","normal"})do local s=ctx.assets:clone("weapons/"..name.."/audio/"..soundName);s:Destroy()end
                end)
            end
            if ticket~=module.equipTicket or ctx.cleanup.dead then return end
            module.loading=false
            if not ctx.core:valid(r) or ctx.avatars:getLocal()~=r then return end
            if not ok then ctx.report("Weapon "..name.." failed: "..tostring(result));return end
            if not ctx.core:free(r) then ctx.status("Weapon change cancelled: your character started an interaction");return end
            module.emoteRecord=nil
            module.selected=name;ctx.weaponChoice=name;r.weapon=name;ctx.core:changed(r,"equip")
            animation(r,"bat/flourish",false);sound(r,"weapons/"..name.."/audio/Equip")
            ctx.status("Equipped "..name)
        end)()
        return true
    end
    function module:selectGender(name)
        if not genders[name]then return false,"Unknown original gender choice"end
        local r=ctx.avatars:getLocal()
        if not ctx.core:free(r)then return false,"Your local avatar must be ready and free"end
        ctx.gender=name;r.gender=name;ctx.core:changed(r,"gender")
        return self:equip(self.selected)
    end
    function module:emote(value)
        local r=ctx.avatars:getLocal();local key=emotes[value]
        if not key or not r or not genders[r.gender]or not ctx.core:free(r)then return false,"Your local avatar must be ready and free"end
        self.active=nil;animation(r,key,true);self.emoteRecord=r
        local cf=ctx.avatars:frame(r);self.emoteOrigin=cf and cf.Position
        return true
    end
    function module:swing()
        local a=ctx.avatars:getLocal()
        if self.loading or not a or a.weapon=="" or not ctx.weapons:get(a.character)then return false,"Weapon is not ready"end
        local attack,why=ctx.core:swing(a,tick());if not attack then return false,why end
        self.active=attack
        self.emoteRecord=nil
        animation(a,"bat/swing_"..attack.combo,false)
        sound(a,"weapons/"..a.weapon.."/audio/Swing")
        ctx.weapons:setTrails(a.character,true);self.trailUntil=attack.ends
        return true
    end
    function module:carry(target)
        local a=ctx.avatars:getLocal();target=target or ctx.avatars:nearest(true)
        if not target then return false,"No nearby local downed target"end
        if ctx.core:canCarry(a,target,ctx.avatars:distance(a,target))then self.emoteRecord=nil end
        local ok,why=ctx.core:carry(a,target,tick(),ctx.avatars:distance(a,target))
        if ok then self.active=nil;ctx.status("Carrying "..target.displayName.." locally")end
        return ok,why
    end
    function module:drop()
        local a=ctx.avatars:getLocal()
        if not a then return false,"Your character is not ready"end
        local ok,why=ctx.core:drop(a,tick());if ok then ctx.status("Dropped local target")end;return ok,why
    end
    function module:glory(target)
        local a=ctx.avatars:getLocal();target=target or ctx.avatars:nearest(true)
        if not a or not target then return false,"No nearby local ragdolled target"end
        local carried=a.carrying==target
        local first=carried and "bat/finishHoldAttacker" or "bat/gripAttacker"
        local second=carried and "bat/finishHoldVictim" or "bat/gripVictim"
        local actor=ctx.animations:preload(first);local victim=ctx.animations:preload(second)
        local ok,why=ctx.core:glory(a,target,tick(),ctx.avatars:distance(a,target),math.max(actor.duration,victim.duration))
        if ok then self.active=nil;self.emoteRecord=nil;animation(a,first,false);animation(target,second,false);ctx.status("Execute · local combat finisher")end
        return ok,why
    end
    function module:pairedDance(target)
        if scope.dead or ctx.cleanup.dead then return false,"Dance controller has been unloaded"end
        local a=ctx.avatars:getLocal();target=target or ctx.avatars:nearest(true)
        if self.loading or not a or not genders[a.gender]then return false,"Choose a gender and finish loading your weapon first"end
        if not target or not ctx.core:canDance(a,target,ctx.avatars:distance(a,target))then return false,"No nearby available ragdolled target for the local dance"end
        local key='Emotes/Boston Breakdance'
        local loaded,clip=pcall(function()return ctx.animations:preload(key)end)
        if not loaded then return false,"Original dance emote failed: "..tostring(clip)end
        if scope.dead or ctx.cleanup.dead then return false,"Dance cancelled: controller was unloaded while loading"end
        if ctx.avatars:getLocal()~=a then return false,"Dance cancelled: your character changed while loading"end
        local actorFrame,victimFrame=sourceFrame(a),sourceFrame(target)
        if not actorFrame or not victimFrame then return false,"Dance cancelled: a participant's source root is unavailable"end
        local now=tick()
        local ok,why=ctx.core:dance(a,target,now,ctx.avatars:distance(a,target),clip.duration)
        if not ok then return false,why end
        self.active=nil;self.emoteRecord=nil;self.danceLink=a.dance
        self.danceOrigins={actorFrame.Position,victimFrame.Position}
        stop(a);stop(target);animation(a,key,false,now);animation(target,key,false,now)
        ctx.status('Local dance · Boston Breakdance');return true
    end
    function module:stopDance(target)
        local a=ctx.avatars:getLocal();local link=a and a.dance
        if not link or link.a~=a or (target and link.v~=target)then return false,"You are not the initiator of this local dance"end
        return ctx.core:stopDance(a,tick())
    end
    function module:dummy()
        local ok,why=ctx.avatars:createDummy();if ok then ctx.status("Local practice dummy created")end;return ok,why
    end
    function module:dash()
        if self.loading then return false,"Weapon is loading"end
        local r=ctx.avatars:getLocal()
        if not r or not genders[r.gender]then return false,"Choose your gender first"end
        if self.emoteRecord then self.emoteRecord=nil;stop(r)end
        return ctx.dash:start(r,tick())
    end
    local function ignoreList()
        local list={ctx.avatars.folder}
        for source in pairs(ctx.avatars.entries)do list[#list+1]=source end
        return list
    end
    local warnedRay=false
    local function unobstructed(from,to)
        local ignored=ignoreList()
        if RaycastParams then
            local ok,result=pcall(function()
                local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=ignored;p.IgnoreWater=true
                return workspace:Raycast(from,to-from,p)
            end)
            if ok then return not result or (result.Position-to).Magnitude<0.5 end
        end
        local ok,hit,position=pcall(function()return workspace:FindPartOnRayWithIgnoreList(Ray.new(from,to-from),ignored)end)
        if ok then return not hit or (position-to).Magnitude<0.5 end
        if not warnedRay then warnedRay=true;ctx.report("No usable local raycast API; weapon hits are disabled")end
        return false
    end
    scope:add(ctx.core:onChanged(function(r,reason)
        if not r.character then return end
        if reason=="ready" and r==ctx.avatars:getLocal() then
            r.gender=ctx.gender
            if genders[r.gender]then ctx.core:changed(r,"gender");module:equip(module.selected)end
        elseif reason=="carry" then
            stop(r);animation(r,"other/carryGrabber",true)
        elseif reason=="carried" then
            stop(r);animation(r,"other/carryGrabbed",true);sound(r,"audio/Carry")
        elseif reason=="drop" or reason=="recover" or reason=="remove" or reason=="gloryEnd" or reason=="danceEnd" then
            stop(r);if reason=="drop" and r.downed then sound(r,"audio/Uncarry")end
            if reason=="danceEnd" and module.danceLink and (r==module.danceLink.a or r==module.danceLink.v)then module.danceLink=nil;module.danceOrigins=nil end
        end
    end))
    scope:add(Run.Heartbeat:Connect(function()
        local now=tick();ctx.core:tick(now)
        local a=ctx.avatars:getLocal()
        local dance=module.danceLink
        if dance and not dance.released then
            local moved=not ctx.core:valid(dance.a) or not ctx.core:valid(dance.v) or a~=dance.a
            for i,r in ipairs({dance.a,dance.v})do
                local cf=sourceFrame(r)
                if not r.character.Parent or not cf or (cf.Position-module.danceOrigins[i]).Magnitude>0.2 then moved=true end
            end
            if moved then ctx.core:releaseDance(dance,now)end
        end
        if module.emoteRecord then
            local r=module.emoteRecord;local cf=ctx.avatars:frame(r)
            if not ctx.core:free(r)or r~=a or not cf or (module.emoteOrigin and (cf.Position-module.emoteOrigin).Magnitude>0.2)then
                module.emoteRecord=nil;stop(r)
            end
        end
        if module.trailUntil and now>=module.trailUntil then module.trailUntil=nil;if a and a.character then ctx.weapons:setTrails(a.character,false)end end
        local attack=module.active
        if not attack then return end
        if not ctx.core:valid(attack.owner) or attack.owner~=a or a.attack~=attack or now>attack.ends then module.active=nil;return end
        if now<attack.start+attack.startup then return end
        local actorFrame=ctx.avatars:frame(a);if not actorFrame then return end
        for _,e in pairs(ctx.avatars.entries)do
            local v=e.record;local targetFrame=ctx.avatars:frame(v)
            if v~=a and targetFrame and not attack.hit[v]then
                local delta=targetFrame.Position-actorFrame.Position
                local distance=delta.Magnitude
                local facing=distance<0.01 or actorFrame.LookVector:Dot(delta.Unit)>=0.05
                if distance<=ctx.config.HitDistance and math.abs(delta.Y)<=4 and facing and unobstructed(actorFrame.Position,targetFrame.Position)then
                    if ctx.core:hit(a,v,attack,now)then
                        v.impulse=actorFrame.LookVector*(attack.combo==3 and 24 or 10)+Vector3.new(0,5,0)
                        sound(v,attack.combo==3 and "audio/Heavy" or "audio/Default")
                        ctx.network:emit("Damage",{attacker=a.character,character=v.character,amount=attack.damage})
                        ctx.status("Local hit: "..v.displayName..(v.downed and " · downed" or ""))
                    end
                end
            end
        end
    end))
    scope:add(function()
        module.equipTicket=module.equipTicket+1;module.active=nil
        local dance=module.danceLink
        if dance then
            ctx.core:releaseDance(dance,tick())
            -- Maid may have already disconnected our danceEnd callback.
            if module.danceLink==dance then
                stop(dance.a);stop(dance.v);module.danceLink=nil;module.danceOrigins=nil
            end
        end
    end)
    local initial=ctx.avatars:getLocal()
    if initial and ctx.core:valid(initial) and genders[ctx.gender]then
        initial.gender=ctx.gender;ctx.core:changed(initial,"gender");module:equip(module.selected)
    end
    function module:destroy()scope:destroy()end
    return module
end
