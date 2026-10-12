-- Local R6 presentation. Never move or rebuild a real character.
return function(ctx)
    local Players=game:GetService("Players")
    local Run=game:GetService("RunService")
    local localPlayer=Players.LocalPlayer
    local scope=ctx.cleanup:scope()
    local module={entries={},byModel={},pending={},localRecord=nil}
    local folder=Instance.new("Folder");folder.Name="FunCombatPortable_Local";folder.Parent=workspace;scope:add(folder)
    module.folder=folder;module.building={};module.dummies={};module.watchers={};module.refresh={}
    local Appearance,Visibility=ctx.modules.appearance,ctx.modules.visibility
    local identity=CFrame.new()
    local collisions=ctx.modules.collision.new(function(p,q)
        local c=Instance.new("NoCollisionConstraint");c.Part0=p;c.Part1=q;c.Parent=p;return c
    end)
    local function clone(object)
        local old=object.Archivable;object.Archivable=true
        local ok,result=pcall(function()return object:Clone()end);object.Archivable=old
        assert(ok and result,"Cannot clone original avatar object: "..object.Name)
        return result
    end
    local function clean(object)
        local all=object:GetDescendants();all[#all+1]=object
        for _,v in ipairs(all) do
            if v~=object and (v:IsA("LuaSourceContainer") or v:IsA("JointInstance") or v:IsA("WeldConstraint")
                or v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("Sound")) then v:Destroy() end
        end
    end
    local function part(name,size,color,parent)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.Plastic
        p.Anchored=true;p.CanCollide=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
        pcall(function()p.CanTouch=false;p.CanQuery=false end);p.Parent=parent;return p
    end
    local function motor(e,name,a,b,c0,c1)
        local m=Instance.new("Motor6D");m.Name=name;m.Part0=e.parts[a];m.Part1=e.parts[b];m.C0=c0;m.C1=c1;m.Parent=m.Part0
        e.motors[#e.motors+1]=m;e.joints[name]=m;return m
    end
    local function cosmetic(object)
        if object:IsA("BasePart") then
            object.Anchored=true;object.CanCollide=false;object.Massless=true;object.LocalTransparencyModifier=0
            pcall(function()object.CanTouch=false;object.CanQuery=false end)
        end
    end
    local function ignoreSource(e,object)
        if object:IsA("BasePart") then
            e.guard:set(object,"LocalTransparencyModifier",1);e.sourceParts[object]=true
        elseif object:IsA("Decal") or object:IsA("Texture") then
            if not e.guard:set(object,"LocalTransparencyModifier",1) then e.guard:set(object,"Transparency",1) end
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then e.guard:set(object,"Enabled",false) end
    end
    function module:remove(source)
        self.pending[source]=nil
        self.refresh[source]=nil
        local watcher=self.watchers[source];self.watchers[source]=nil
        if watcher then watcher:destroy()end
        local e=self.entries[source]
        local building=self.building[source];self.building[source]=nil
        if not e then if building then building:destroy()end;return end
        self.entries[source]=nil;self.byModel[e.model]=nil
        if self.localRecord==e.record then self.localRecord=nil end
        ctx.core:detach(e.record,tick());ctx.network:emit("Remove",{character=e.model})
        e.scope:destroy()
    end
    function module:queue(source,player)
        if self.entries[source] or self.pending[source] or source:IsDescendantOf(folder) then return end
        if not self.watchers[source]then
            local watcher=scope:scope();self.watchers[source]=watcher
            local tracked={}
            local function arriving(object)
                if object:IsA("BasePart")then tracked[object]=true;collisions:track(object)end
                if module.entries[source] and Appearance.affects(object,source)then module.refresh[source]={at=tick()+0.25,player=player}end
            end
            for _,object in ipairs(source:GetDescendants())do arriving(object)end
            watcher:add(source.DescendantAdded:Connect(arriving))
            watcher:add(source.DescendantRemoving:Connect(function(object)
                if tracked[object]then tracked[object]=nil;collisions:untrack(object)end
                if module.entries[source] and Appearance.affects(object,source)then module.refresh[source]={at=tick()+0.25,player=player}end
            end))
            watcher:add(source.AncestryChanged:Connect(function(_,parent)if not parent then module:remove(source)end end))
            watcher:add(function()for object in pairs(tracked)do collisions:untrack(object)end end)
        end
        self.pending[source]={player=player,deadline=tick()+ctx.config.Timeout}
    end
    local function build(source,player)
        local hum=source:FindFirstChildOfClass("Humanoid")
        local root=source:FindFirstChild("HumanoidRootPart")
        local sourceHead=source:FindFirstChild("Head")
        if not hum or not root or not sourceHead or not root:IsA("BasePart") or not sourceHead:IsA("BasePart") or hum.Health<=0 then return nil end
        local childScope=scope:scope()
        module.building[source]=childScope
        local model=Instance.new("Model");model.Name="FC_Local_"..(player and tostring(player.UserId) or source.Name);childScope:add(model)
        local e={scope=childScope,model=model,source=source,humanoid=hum,root=root,player=player,parts={},motors={},joints={},accessories={},sourceParts={},phase=0,bones={}}
        e.guard=Visibility.new();childScope:add(e.guard)
        local gray=Color3.fromRGB(163,162,165)
        e.parts.HumanoidRootPart=part("HumanoidRootPart",Vector3.new(2,2,1),gray,model);e.parts.HumanoidRootPart.Transparency=1
        e.parts.Torso=part("Torso",Vector3.new(2,2,1),Appearance.color(source,"Torso",gray),model)
        for _,name in ipairs({"Left Arm","Right Arm","Left Leg","Right Leg"}) do e.parts[name]=part(name,Vector3.new(1,2,1),Appearance.color(source,name,gray),model) end
        local head=clone(sourceHead);clean(head);head.Name="Head";head.Color=Appearance.color(source,"Head",head.Color);cosmetic(head);head.Parent=model;e.parts.Head=head
        local boneSources={}
        for _,b in ipairs(sourceHead:GetDescendants())do if b:IsA("Bone")then boneSources[b.Name]=b end end
        for _,b in ipairs(head:GetDescendants())do if b:IsA("Bone") and boneSources[b.Name] then e.bones[#e.bones+1]={b,boneSources[b.Name]}end end
        local h=Instance.new("Humanoid");h.Name="Humanoid";h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.PlatformStand=true
        h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;h.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
        pcall(function()h.EvaluateStateMachine=false end);h.Parent=model
        local flip=CFrame.Angles(-math.pi/2,0,math.pi)
        motor(e,"RootJoint","HumanoidRootPart","Torso",flip,flip)
        motor(e,"Neck","Torso","Head",CFrame.new(0,1,0)*flip,CFrame.new(0,-head.Size.Y/2,0)*flip)
        motor(e,"Right Shoulder","Torso","Right Arm",CFrame.new(1,0.5,0)*CFrame.Angles(0,math.pi/2,0),CFrame.new(-0.5,0.5,0)*CFrame.Angles(0,math.pi/2,0))
        motor(e,"Left Shoulder","Torso","Left Arm",CFrame.new(-1,0.5,0)*CFrame.Angles(0,-math.pi/2,0),CFrame.new(0.5,0.5,0)*CFrame.Angles(0,-math.pi/2,0))
        motor(e,"Right Hip","Torso","Right Leg",CFrame.new(1,-1,0)*CFrame.Angles(0,math.pi/2,0),CFrame.new(0.5,1,0)*CFrame.Angles(0,math.pi/2,0))
        motor(e,"Left Hip","Torso","Left Leg",CFrame.new(-1,-1,0)*CFrame.Angles(0,-math.pi/2,0),CFrame.new(-0.5,1,0)*CFrame.Angles(0,-math.pi/2,0))
        local grip=Instance.new("Attachment");grip.Name="RightGripAttachment";grip.CFrame=CFrame.new(0,-1,0);grip.Parent=e.parts["Right Arm"]
        for _,object in ipairs(source:GetChildren()) do
            if object:IsA("Shirt") or object:IsA("Pants") or object:IsA("ShirtGraphic") or object:IsA("BodyColors") then clone(object).Parent=model
            elseif object:IsA("Accessory") and not object:FindFirstChildWhichIsA("WrapLayer",true) then
                local original=object:FindFirstChild("Handle")
                if original and original:IsA("BasePart") then
                    local attachment=original:FindFirstChildOfClass("Attachment")
                    if not attachment or sourceHead:FindFirstChild(attachment.Name,true) then
                        local acc=clone(object);clean(acc);acc.Parent=model
                        local handle=acc:FindFirstChild("Handle")
                        if handle then
                            for _,p in ipairs(acc:GetDescendants())do cosmetic(p)end
                            local offset=sourceHead.CFrame:ToObjectSpace(original.CFrame)
                            local w=Instance.new("Weld");w.Part0=head;w.Part1=handle;w.C0=offset;w.Parent=handle
                            e.accessories[#e.accessories+1]={handle,offset}
                        end
                    end
                end
            end
        end
        model.PrimaryPart=e.parts.HumanoidRootPart;model.Parent=folder
        local r=ctx.core:register(source);e.record=r;r.character=model;r.displayName=player and player.DisplayName or source.Name;r.avatar=e
        module.entries[source]=e;module.byModel[model]=r
        if player==localPlayer then module.localRecord=r end
        for _,object in ipairs(source:GetDescendants())do ignoreSource(e,object)end
        e.guard:set(hum,"DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None)
        childScope:add(source.DescendantAdded:Connect(function(o)ignoreSource(e,o)end))
        childScope:add(source.AncestryChanged:Connect(function(_,parent)if not parent then module:remove(source)end end))
        local prompt=Instance.new("ProximityPrompt");prompt.Name="FC_LocalCarry";prompt.ActionText="Carry";prompt.ObjectText=r.displayName
        prompt.KeyboardKeyCode=Enum.KeyCode.T;prompt.HoldDuration=0.3;prompt.MaxActivationDistance=ctx.config.InteractDistance
        prompt.RequiresLineOfSight=false;prompt.Enabled=false;prompt.Parent=e.parts.Torso;e.prompt=prompt
        childScope:add(prompt.Triggered:Connect(function(sender)
            if sender==localPlayer and ctx.controller then
                if r.carriedBy==module.localRecord then ctx.controller:drop()else ctx.controller:carry(r)end
            end
        end))
        local glory=Instance.new("ProximityPrompt");glory.Name="FC_LocalGlory";glory.ActionText="Glory";glory.ObjectText=r.displayName
        glory.KeyboardKeyCode=Enum.KeyCode.E;glory.HoldDuration=0.3;glory.MaxActivationDistance=ctx.config.InteractDistance
        glory.RequiresLineOfSight=false;glory.Enabled=false;glory.Parent=e.parts.Torso;e.gloryPrompt=glory
        childScope:add(glory.Triggered:Connect(function(sender)
            if sender==localPlayer and ctx.controller then ctx.controller:glory(r)end
        end))
        module.building[source]=nil
        ctx.core:changed(r,"ready")
        return e
    end
    function module:getLocal()return self.localRecord end
    function module:frame(r)
        local e=r and r.avatar
        if not e or not e.model.Parent then return nil end
        if e.ragdoll then return e.parts.Torso.CFrame end
        if r.link and r.link.v==r then
            local a=r.link.a.avatar;if a and a.root.Parent then return a.root.CFrame end
        end
        if r.carriedBy then local a=r.carriedBy.avatar;if a and a.root.Parent then return a.root.CFrame*CFrame.new(0,0,-2.4)end end
        return e.root.Parent and e.root.CFrame or nil
    end
    function module:distance(a,v)
        local ac,vc=self:frame(a),self:frame(v)
        return ac and vc and (ac.Position-vc.Position).Magnitude or math.huge
    end
    function module:nearest(downedOnly)
        local a=self.localRecord;if not a then return nil end
        local best,range=nil,ctx.config.InteractDistance
        for _,e in pairs(self.entries)do
            local v=e.record;local d=self:distance(a,v)
            if v~=a and ctx.core:valid(v) and (not downedOnly or v.downed or v.ragdolled) and not v.carriedBy and d<=range then best,range=v,d end
        end
        return best
    end
    function module:setRagdoll(e,value)
        if (e.ragdoll~=nil)==value then return end
        if not value then
            collisions:stop(e)
            e.ragdoll:destroy();e.ragdoll=nil
            for _,m in ipairs(e.motors)do m.Enabled=true;m.Transform=identity end
            for _,p in pairs(e.parts)do if p.Parent then p.Anchored=true;p.CanCollide=false end end
            for _,a in ipairs(e.accessories)do if a[1].Parent then a[1].Anchored=true end end
            return
        end
        if ctx.animations then ctx.animations:stop(e.model)end
        local rag=e.scope:scope();e.ragdoll=rag
        for _,m in ipairs(e.motors)do
            if m.Name~="RootJoint" then
                local x,y=Instance.new("Attachment"),Instance.new("Attachment")
                x.CFrame=m.C0*m.Transform;y.CFrame=m.C1;x.Parent=m.Part0;y.Parent=m.Part1;rag:add(x);rag:add(y)
                local socket=Instance.new("BallSocketConstraint");socket.Attachment0=x;socket.Attachment1=y
                socket.LimitsEnabled=true;socket.UpperAngle=m.Name=="Neck" and 35 or 65;socket.Parent=m.Part0;rag:add(socket);m.Enabled=false
            end
        end
        local bodies={}
        for name,p in pairs(e.parts)do
            p.Anchored=false;p.CanCollide=name~="HumanoidRootPart"
            if p.CanCollide then bodies[#bodies+1]=p end
        end
        for _,a in ipairs(e.accessories)do a[1].Anchored=false end
        local function noContact(p,q)
            local c=Instance.new("NoCollisionConstraint");c.Part0=p;c.Part1=q;c.Parent=p;rag:add(c)
        end
        for i,p in ipairs(bodies)do
            for j=i+1,#bodies do noContact(p,bodies[j])end
            local velocity=e.record.impulse or Vector3.new(0,2,0)
            pcall(function()p.AssemblyLinearVelocity=velocity end)
        end
        collisions:start(e,bodies,rag);rag:add(function()collisions:stop(e)end)
        e.record.impulse=nil
    end
    local function pose(e,dt)
        local r=e.record
        local cf=module:frame(r);if not cf then return end
        local moving=not r.carriedBy and not r.downed
        local got,velocity=pcall(function()return e.root.AssemblyLinearVelocity end)
        if not got then velocity=e.root.Velocity end
        local speed=moving and Vector3.new(velocity.X,0,velocity.Z).Magnitude or 0
        e.phase=e.phase+dt*math.min(18,speed*0.8)
        local gait=math.sin(e.phase)*math.min(0.7,speed/24)
        local hipsOwned=ctx.animations and ctx.animations:blocksLocomotion(e.model)
        if not hipsOwned then
            e.joints["Right Hip"].Transform=CFrame.Angles(0,0,gait)
            e.joints["Left Hip"].Transform=CFrame.Angles(0,0,gait)
        end
        if not ctx.animations or not ctx.animations:isPlaying(e.model)then
            e.joints["Right Shoulder"].Transform=CFrame.Angles(0,0,-gait)
            e.joints["Left Shoulder"].Transform=CFrame.Angles(0,0,-gait)
        end
        e.parts.HumanoidRootPart.CFrame=cf
        for _,m in ipairs(e.motors)do if m.Enabled and m.Part0.Parent and m.Part1.Parent then m.Part1.CFrame=m.Part0.CFrame*m.C0*m.Transform*m.C1:Inverse()end end
        for _,a in ipairs(e.accessories)do if a[1].Parent then a[1].CFrame=e.parts.Head.CFrame*a[2]end end
        for _,b in ipairs(e.bones)do if b[1].Parent and b[2].Parent then b[1].Transform=b[2].Transform end end
        if e.player==localPlayer then
            local camera=workspace.CurrentCamera
            local firstPerson=camera and (camera.CFrame.Position-e.parts.Head.Position).Magnitude<1.2
            e.parts.Head.LocalTransparencyModifier=firstPerson and 1 or 0
            for _,a in ipairs(e.accessories)do a[1].LocalTransparencyModifier=firstPerson and 1 or 0 end
        end
    end
    local function playerAdded(player)
        scope:add(player.CharacterAdded:Connect(function(c)module:queue(c,player)end))
        scope:add(player.CharacterRemoving:Connect(function(c)module:remove(c)end))
        if player.Character then module:queue(player.Character,player)end
    end
    for _,p in ipairs(Players:GetPlayers())do playerAdded(p)end
    scope:add(Players.PlayerAdded:Connect(playerAdded))
    scope:add(Players.PlayerRemoving:Connect(function(p)if p.Character then module:remove(p.Character)end end))
    scope:add(workspace.DescendantAdded:Connect(function(o)
        if o:IsA("Humanoid") and not o:IsDescendantOf(folder)then
            local source=o.Parent
            if source and source:IsA("Model")then module:queue(source,Players:GetPlayerFromCharacter(source))end
        end
    end))
    for _,o in ipairs(workspace:GetDescendants())do if o:IsA("Humanoid")and not o:IsDescendantOf(folder)then local s=o.Parent;if s and s:IsA("Model")then module:queue(s,Players:GetPlayerFromCharacter(s))end end end
    scope:add(Run.Heartbeat:Connect(function()
        local now=tick()
        for source,refresh in pairs(module.refresh)do
            if now>=refresh.at then
                module:remove(source)
                if source.Parent and (not refresh.player or refresh.player.Character==source)then module:queue(source,refresh.player)end
            end
        end
        for source,p in pairs(module.pending)do
            local current=not p.player or p.player.Character==source
            if not current or now>=p.deadline then
                module.pending[source]=nil
                if current then ctx.report("Blocky avatar did not mount within "..ctx.config.Timeout.."s: "..source.Name)end
            elseif Appearance.current(source,p.player and function()return p.player.Character end or nil) and source:IsDescendantOf(workspace)then
                local ok,result=pcall(build,source,p.player)
                if not ok then module:remove(source);ctx.report("Blocky avatar failed: "..source.Name..": "..tostring(result))
                elseif result then module.pending[source]=nil end
            end
        end
        local remove={}
        for source,e in pairs(module.entries)do
            if not source.Parent or not e.root.Parent or e.humanoid.Health<=0 or not e.parts.Torso.Parent or not e.parts.Head.Parent then remove[#remove+1]=source
            else
                module:setRagdoll(e,e.record.ragdolled==true)
                local a=module.localRecord
                e.prompt.ActionText=e.record.carriedBy==a and "Drop" or "Carry"
                e.prompt.Enabled=a~=nil and e.record~=a and ((e.record.carriedBy==a) or ctx.core:canCarry(a,e.record,module:distance(a,e.record))) or false
                e.gloryPrompt.Enabled=a~=nil and e.record~=a and ctx.core:canGlory(a,e.record,module:distance(a,e.record)) or false
            end
        end
        for _,source in ipairs(remove)do module:remove(source)end
    end))
    scope:add(Run.RenderStepped:Connect(function(dt)
        for _,e in pairs(module.entries)do if not e.ragdoll and e.root.Parent then pose(e,dt)end end
    end))
    function module:createDummy()
        if not localPlayer.Character then return false,"Your character is not ready"end
        local r=self.localRecord;if not r then return false,"Your local avatar is not ready"end
        local count=0;for source in pairs(self.dummies)do if source.Parent then count=count+1 else self.dummies[source]=nil end end
        if count>=3 then return false,"Three local practice dummies already exist"end
        local source=clone(localPlayer.Character);source.Name="Local practice dummy";clean(source);scope:add(source)
        local h=source:FindFirstChildOfClass("Humanoid")
        if h then h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.PlatformStand=true;pcall(function()h.EvaluateStateMachine=false end)end
        local origin=self:frame(r)*CFrame.new(0,0,-5)
        local root=source:FindFirstChild("HumanoidRootPart");if not root then source:Destroy();return false,"Source character has no root"end
        local delta=origin*root.CFrame:Inverse()
        for _,p in ipairs(source:GetDescendants())do if p:IsA("BasePart")then p.CFrame=delta*p.CFrame;p.Anchored=true;p.CanCollide=false end end
        self.dummies[source]=true;source.Parent=workspace;self:queue(source,nil);return true
    end
    scope:add(function()
        local sources={};for source in pairs(module.entries)do sources[#sources+1]=source end
        for _,source in ipairs(sources)do module:remove(source)end
        module.pending={}
    end)
    function module:destroy()scope:destroy()end
    return module
end
