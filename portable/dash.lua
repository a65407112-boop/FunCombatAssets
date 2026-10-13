-- Original 18-stud/0.3s horizontal dash, on the local player's actual character.
return function(ctx)
    local scope=ctx.cleanup:scope();local module={active=nil,nextAt=0}
    local function eligible(actor)
        if not actor or actor~=ctx.avatars:getLocal()or not ctx.core:valid(actor)or not ctx.core:free(actor)or actor.weapon==''then return false end
        local e=actor.avatar;local root=e and e.root;local h=e and e.humanoid
        return root and root.Parent and not root.Anchored and h and h.Parent and h.Health>0 and not h.Sit and not h.PlatformStand
    end
    local function blocked(root,direction)
        if ctx.dashBlocked then return ctx.dashBlocked(root,direction)end
        local ignore={ctx.avatars.folder};for source in pairs(ctx.avatars.entries)do ignore[#ignore+1]=source end
        local ok,hit
        if RaycastParams then
            ok,hit=pcall(function()
                local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=ignore
                return workspace:Raycast(root.Position,direction*3,p)
            end)
            if ok then return hit~=nil end
        end
        ok,hit=pcall(function()return workspace:FindPartOnRayWithIgnoreList(Ray.new(root.Position,direction*3),ignore)end)
        return not ok or hit~=nil
    end
    function module:cancel()
        local a=self.active;self.active=nil
        if not a then return end
        if a.body then scope:remove(a.body);a.body:Destroy()end
        a.actor.dashing=false
        ctx.network:emit('DashStop',{character=a.actor.character})
        if ctx.core:valid(a.actor)then ctx.core:changed(a.actor,'dashEnd')end
    end
    function module:start(actor,now)
        if not eligible(actor)then return false,'Your character must be alive, mobile and free to dash'end
        if self.active or now<self.nextAt then return false,'Dash is cooling down'end
        local e=actor.avatar
        if e.passive and not e.passive:check()then return false,'Unsafe visual copy was removed'end
        local input=e.humanoid.MoveDirection
        local d=Vector3.new(input.X,0,input.Z)
        if d.Magnitude<0.01 then local look=e.root.CFrame.LookVector;d=Vector3.new(look.X,0,look.Z)end
        if d.Magnitude<0.01 or d.X~=d.X or d.Z~=d.Z or math.abs(d.X)==math.huge or math.abs(d.Z)==math.huge then return false,'No valid horizontal dash direction'end
        d=d.Unit
        if blocked(e.root,d)then return false,'Dash path is blocked'end
        self.nextAt=now+1.35;self.active={actor=actor,root=e.root,direction=d,at=now+0.15,ends=now+0.45}
        actor.dashing=true;ctx.core:changed(actor,'dashStart')
        ctx.network:emit('Sound',{character=actor.character,key='weapons/'..actor.weapon..'/audio/DashSound'})
        ctx.network:emit('Sound',{character=actor.character,key='weapons/'..actor.weapon..'/audio/normal'})
        ctx.network:emit('Effect',{character=actor.character,key='effects/dash_limbs',duration=0.3})
        if e.humanoid.FloorMaterial~=Enum.Material.Air then ctx.network:emit('Effect',{character=actor.character,key='effects/dash_smoke',duration=0.3})end
        return true
    end
    function module:step(now)
        local a=self.active;if not a then return end
        if not eligible(a.actor)or a.root~=a.actor.avatar.root or now>=a.ends or blocked(a.root,a.direction)then self:cancel();return end
        if now>=a.at and not a.body then
            local body=Instance.new('BodyVelocity');body.Name='FunCombatPortable_Dash'
            body.MaxForce=Vector3.new(30000,0,30000);body.Velocity=a.direction*60
            scope:add(body);body.Parent=a.root;a.body=body
        end
    end
    local run=game:GetService('RunService');local ok,event=pcall(function()return run.PreSimulation end)
    if not ok or not event then event=run.Stepped or run.Heartbeat end
    scope:add(event:Connect(function()module:step(tick())end))
    scope:add(function()module:cancel()end)
    function module:destroy()scope:destroy()end
    return module
end
