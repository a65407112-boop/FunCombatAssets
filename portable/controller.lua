return function(ctx)
    local Run=game:GetService("RunService")
    local scope=ctx.cleanup:scope()
    local module={selected=ctx.config.DefaultWeapon,equipTicket=0,active=nil}
    local function state(r)return ctx.state:get(r.character)end
    local function sound(r,key)
        if r and r.character and r.character.Parent then ctx.network:emit("Sound",{character=r.character,key=key})end
    end
    local function animation(r,key,loop)
        if not r or not r.character then return end
        r.revision=r.revision+1
        ctx.network:emit("Animation",{character=r.character,key=key,start=tick(),revision=r.revision,loop=loop})
    end
    local function stop(r)
        if not r or not r.character then return end
        r.revision=r.revision+1;ctx.network:emit("StopAnimation",{character=r.character,revision=r.revision})
        ctx.weapons:setTrails(r.character,false)
    end
    function module:equip(name)
        if not ctx.catalog.packages["weapons/"..tostring(name)] then return false,"Unknown original weapon"end
        local r=ctx.avatars:getLocal()
        if not ctx.core:free(r)then return false,"Your local avatar must be ready and free"end
        self.equipTicket=self.equipTicket+1;local ticket=self.equipTicket
        self.loading=true;ctx.status("Loading "..name.."...")
        coroutine.wrap(function()
            local ok,result=pcall(function()return ctx.assets:clone("weapons/"..name)end)
            if ok then result:Destroy()end
            if ticket~=module.equipTicket or ctx.cleanup.dead then return end
            module.loading=false
            if not ctx.core:valid(r) or ctx.avatars:getLocal()~=r then return end
            if not ok then ctx.report("Weapon "..name.." failed: "..tostring(result));return end
            if not ctx.core:free(r) then ctx.status("Weapon change cancelled: your character started an interaction");return end
            module.selected=name;r.weapon=name;ctx.core:changed(r,"equip")
            animation(r,"bat/flourish",false);sound(r,"weapons/"..name.."/audio/Equip")
            ctx.status("Equipped "..name)
        end)()
        return true
    end
    function module:swing()
        local a=ctx.avatars:getLocal()
        if self.loading or not a or a.weapon=="" or not ctx.weapons:get(a.character)then return false,"Weapon is not ready"end
        local attack,why=ctx.core:swing(a,tick());if not attack then return false,why end
        self.active=attack
        animation(a,"bat/swing_"..attack.combo,false)
        sound(a,"weapons/"..a.weapon.."/audio/Swing")
        ctx.weapons:setTrails(a.character,true);self.trailUntil=attack.ends
        return true
    end
    function module:carry(target)
        local a=ctx.avatars:getLocal();target=target or ctx.avatars:nearest(true)
        if not target then return false,"No nearby local downed target"end
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
        if ok then self.active=nil;animation(a,first,false);animation(target,second,false);ctx.status("Glory · local combat finisher")end
        return ok,why
    end
    function module:dummy()
        local ok,why=ctx.avatars:createDummy();if ok then ctx.status("Local practice dummy created")end;return ok,why
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
        if reason=="ready" and r==ctx.avatars:getLocal() then module:equip(module.selected)
        elseif reason=="carry" then
            stop(r);animation(r,"other/carryGrabber",true)
        elseif reason=="carried" then
            stop(r);animation(r,"other/carryGrabbed",true);sound(r,"audio/Carry")
        elseif reason=="drop" or reason=="recover" or reason=="remove" or reason=="gloryEnd" then
            stop(r);if reason=="drop" and r.downed then sound(r,"audio/Uncarry")end
        end
    end))
    scope:add(Run.Heartbeat:Connect(function()
        local now=tick();ctx.core:tick(now)
        local a=ctx.avatars:getLocal()
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
                        ctx.status("Local hit: "..v.displayName..(v.downed and " · downed" or ""))
                    end
                end
            end
        end
    end))
    scope:add(function()module.equipTicket=module.equipTicket+1;module.active=nil end)
    function module:destroy()scope:destroy()end
    return module
end
