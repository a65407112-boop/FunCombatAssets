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
    local Ragdoll=ctx.modules.ragdoll
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
            local function arriving(object)
                if module.entries[source] and Appearance.affects(object,source)then module.refresh[source]={at=tick()+0.25,player=player}end
            end
            for _,object in ipairs(source:GetDescendants())do arriving(object)end
            watcher:add(source.DescendantAdded:Connect(arriving))
            watcher:add(source.DescendantRemoving:Connect(function(object)
                if module.entries[source] and Appearance.affects(object,source)then module.refresh[source]={at=tick()+0.25,player=player}end
            end))
            watcher:add(source.AncestryChanged:Connect(function(_,parent)if not parent then module:remove(source)end end))
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
        for _,object in ipairs(head:GetDescendants())do cosmetic(object)end
        local boneSources={}
        for _,b in ipairs(sourceHead:GetDescendants())do if b:IsA("Bone")then boneSources[b.Name]=b end end
        for _,b in ipairs(head:GetDescendants())do if b:IsA("Bone") and boneSources[b.Name] then e.bones[#e.bones+1]={b,boneSources[b.Name]}end end
        local h=Instance.new("Humanoid");h.Name="Humanoid";h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.PlatformStand=true
        h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;h.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
        h.Parent=model
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
        model.PrimaryPart=e.parts.HumanoidRootPart
        e.passive=ctx.modules.passive.install(model,h,childScope,function(message)
            module:remove(source);ctx.report(message..'; unsafe visual copy removed')
        end)
        model.Parent=folder
        local r=ctx.core:register(source);e.record=r;r.character=model;r.displayName=player and player.DisplayName or source.Name;r.avatar=e
        r.userId=player and player.UserId or 0
        local ok,gender=pcall(function()return source:GetAttribute("Gender")or source:GetAttribute("63d6344b9bdc")end)
        if player==localPlayer then r.gender=ctx.gender else r.gender=ok and gender or nil end
        module.entries[source]=e;module.byModel[model]=r
        if player==localPlayer then module.localRecord=r end
        for _,object in ipairs(source:GetDescendants())do ignoreSource(e,object)end
        e.guard:set(hum,"DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None)
        childScope:add(source.DescendantAdded:Connect(function(o)ignoreSource(e,o)end))
        childScope:add(source.AncestryChanged:Connect(function(_,parent)if not parent then module:remove(source)end end))
        ctx.modules.prompts(ctx,e,localPlayer)
        module.building[source]=nil
        ctx.core:changed(r,"ready")
        return e
    end
    function module:getLocal()return self.localRecord end
    function module:sourceFrame(r)
        local e=r and r.avatar
        return e and e.root.Parent and e.root.CFrame or nil
    end
    function module:frame(r)
        local e=r and r.avatar
        if not e or not e.model.Parent then return nil end
        -- The dance adaptation arranges only our proxy; actual roots stay untouched.
        if r.dance and r.dance.v==r then
            local cf=self:sourceFrame(r.dance.a)
            if cf then return cf*CFrame.new(3,0,0)end
        end
        if e.ragdoll then return e.ragFrame or e.parts.Torso.CFrame end
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
            e.ragdoll=nil;e.ragFrame=nil
            for _,m in ipairs(e.motors)do m.Enabled=true;m.Transform=identity end
            return
        end
        if ctx.animations then ctx.animations:stop(e.model)end
        local cf=e.parts.HumanoidRootPart.CFrame;local position=cf.Position
        local velocity=e.record.impulse or Vector3.new(0,2,0)
        local _,yaw=cf:ToOrientation()
        e.ragdoll=Ragdoll.new({x=position.X,y=position.Y,z=position.Z},{x=velocity.X,y=velocity.Y,z=velocity.Z})
        e.ragdoll.yaw=yaw;e.ragFrame=cf
        e.record.impulse=nil
    end
    local warnedProbe=false
    local function mapRay(origin,direction)
        local ignored={folder};for source in pairs(module.watchers)do ignored[#ignored+1]=source end
        local ok,hit,normal
        if RaycastParams then
            ok,hit=pcall(function()
                local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=ignored;p.IgnoreWater=true
                return workspace:Raycast(origin,direction,p)
            end)
            if ok then return hit and hit.Position,hit and hit.Normal,true end
        end
        ok,hit,origin,normal=pcall(function()return workspace:FindPartOnRayWithIgnoreList(Ray.new(origin,direction),ignored)end)
        if ok then return hit and origin,hit and normal,true end
        if not warnedProbe then warnedProbe=true;ctx.report("Map raycast API unavailable; ragdoll stays at its last safe visual position")end
        return nil,nil,false
    end
    local function ragPose(e,dt)
        local rag=e.ragdoll
        Ragdoll.step(rag,dt,workspace.Gravity,function(old,nextPosition)
            return Ragdoll.contact(old,nextPosition,function(origin,direction)
                local hit,normal,supported=mapRay(Vector3.new(origin.x,origin.y,origin.z),Vector3.new(direction.x,direction.y,direction.z))
                return hit and {x=hit.X,y=hit.Y,z=hit.Z},normal and {x=normal.X,y=normal.Y,z=normal.Z},supported
            end)
        end)
        local p=rag.position;local blend=math.min(1,rag.age*5)
        e.ragFrame=CFrame.new(p.x,p.y,p.z)*CFrame.Angles(-math.pi/2*blend,rag.yaw,0)
        local loose=math.sin(rag.age*6)*math.exp(-rag.age*2)*0.35
        for _,m in ipairs(e.motors)do
            if m.Name=="Right Shoulder"then m.Transform=CFrame.Angles(0,0,0.6+loose)
            elseif m.Name=="Left Shoulder"then m.Transform=CFrame.Angles(0,0,-0.6-loose)
            elseif m.Name=="Right Hip"then m.Transform=CFrame.Angles(loose,0,0.15)
            elseif m.Name=="Left Hip"then m.Transform=CFrame.Angles(-loose,0,-0.15)
            else m.Transform=identity end
        end
    end
    function module:showHitboxes(value)
        self.hitboxes=value==true
        for _,e in pairs(self.entries)do
            if e.hitbox then e.hitbox:Destroy();e.hitbox=nil end
            if self.hitboxes then
                local box=Instance.new("SelectionBox");box.Name="FC_LocalHitbox";box.Adornee=e.parts.Torso
                box.Color3=Color3.fromRGB(50,255,140);box.LineThickness=0.04;box.Parent=e.model;e.hitbox=box
            end
        end
    end
    local function pose(e,dt)
        local r=e.record
        if e.ragdoll then ragPose(e,dt)end
        local cf=module:frame(r);if not cf then return end
        e.parts.HumanoidRootPart.CFrame=cf
        for _,m in ipairs(e.motors)do if m.Enabled and m.Part0.Parent and m.Part1.Parent then m.Part1.CFrame=m.Part0.CFrame*m.C0*m.Transform*m.C1:Inverse()end end
        for _,a in ipairs(e.accessories)do if a[1].Parent then a[1].CFrame=e.parts.Head.CFrame*a[2]end end
        if ctx.weapons then ctx.weapons:draw(e.model)end
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
                e.updatePrompts(a,module:distance(a,e.record))
            end
        end
        for _,source in ipairs(remove)do module:remove(source)end
    end))
    scope:add(Run.RenderStepped:Connect(function(dt)
        for _,e in pairs(module.entries)do if e.root.Parent then pose(e,dt)end end
    end))
    local supported,simulationStep=pcall(function()return Run.PreSimulation end)
    if not supported or not simulationStep then simulationStep=Run.Stepped or Run.Heartbeat end
    scope:add(simulationStep:Connect(function()
        for _,e in pairs(module.entries)do if e.passive then e.passive:check()end end
    end))
    function module:createDummy()
        if not localPlayer.Character then return false,"Your character is not ready"end
        local r=self.localRecord;if not r then return false,"Your local avatar is not ready"end
        local count=0;for source in pairs(self.dummies)do if source.Parent then count=count+1 else self.dummies[source]=nil end end
        if count>=3 then return false,"Three local practice dummies already exist"end
        local source=clone(localPlayer.Character);source.Name="Local practice dummy";clean(source);scope:add(source)
        local h=source:FindFirstChildOfClass("Humanoid")
        if h then
            h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.PlatformStand=true
            local disabled,why=ctx.modules.passive.prepareHumanoid(h)
            if not disabled then source:Destroy();return false,why end
        end
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
