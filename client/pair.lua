-- Recreates the source NewChanger models and meter from server-owned state.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local player=game:GetService("Players").LocalPlayer
    local input=game:GetService("UserInputService")
    local run=game:GetService("RunService")
    local ts=game:GetService("TweenService")
    local starter=game:GetService("StarterGui")
    local handles,pending={},{}
    local module={}
    -- Fail concretely at bootstrap if the executor cannot deserialize the two
    -- original models. A blank costume would conceal a missing dependency.
    for _,name in ipairs(ctx.catalog.costumes or {}) do local model=ctx.assets:clone("costumes/"..name);model:Destroy() end
    local function clear(character)
        pending[character]=nil
        local h=handles[character]
        if h then handles[character]=nil;h.scope:destroy() end
    end
    function module:apply(state)
        local character=state and state.character
        if not character then return end
        local name
        if state.pairVictim then name=state.pairTag=="FD" and "TorsoRig" or "LowerRig"
        elseif state.pairActor then name=state.pairTag=="FD" and "LowerRig" or "TorsoRig" end
        local existing=handles[character]
        if not name or not character.Parent then clear(character);return end
        if existing and existing.name==name then return end
        if existing then clear(character) end
        local torso=character:FindFirstChild("Torso")
        local root=character:FindFirstChild("HumanoidRootPart")
        if not torso or not root then pending[character]=pending[character] or {deadline=tick()+10,state=state};return end
        pending[character]=nil
        local s=scope:scope()
        local model=ctx.assets:clone("costumes/"..name);s:add(model)
        local h={scope=s,name=name,model=model};handles[character]=h
        local transparency=torso.Transparency
        torso.Transparency=1
        local clothing={}
        for _,object in ipairs(character:GetChildren()) do
            if object:IsA("Shirt") or object:IsA("Pants") then clothing[object]=object.Parent;object.Parent=root end
        end
        s:add(function()
            if handles[character]==h then handles[character]=nil end
            if torso.Parent and torso.Transparency==1 then torso.Transparency=transparency end
            for object,parent in pairs(clothing) do if object.Parent==root and parent.Parent then object.Parent=parent end end
        end)
        local ref=assert(model:FindFirstChild("ref"),"Original costume lacks ref: "..name)
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name:find("skin") or part.Name=="LeftTorsoPanel" or part.Name=="RightTorsoPanel" then part.Color=torso.Color end
                -- Cosmetic clones do not participate in authoritative physics.
                part.CanCollide=false;part.Massless=true;part.Anchored=false
                pcall(function() part.CanTouch=false;part.CanQuery=false end)
            end
        end
        ref.CFrame=torso.CFrame
        model.Parent=character
        local weld=Instance.new("Weld");weld.Part0=torso;weld.Part1=ref;weld.Parent=torso;s:add(weld)
        local movables=ref:FindFirstChild("Movables")
        if movables then
            for _,joint in ipairs(movables:GetChildren()) do
                if joint:IsA("Motor6D") then
                    local target=movables:FindFirstChild(joint.Name)
                    -- A Motor and a Part can share the source name.
                    for _,part in ipairs(movables:GetChildren()) do if part:IsA("BasePart") and part.Name==joint.Name then target=part;break end end
                    assert(target and target:IsA("BasePart"),"Original costume Motor6D target is missing: "..joint.Name)
                    joint.Part0=torso;joint.Part1=target;joint.Parent=torso;s:add(joint)
                end
            end
        end
        s:add(character.AncestryChanged:Connect(function(_,parent) if not parent then clear(character) end end))
    end
    local meter=ctx.gui.roots.meter
    local frame=meter and meter:FindFirstChild("Frame")
    local container=frame and frame:FindFirstChild("container")
    local bar=container and container:FindFirstChild("bar")
    local label=meter and meter:FindFirstChild("TextLabel")
    local white=meter and meter:FindFirstChild("white")
    local mobile=ctx.gui.roots.mobileButtons
    local button=mobile and mobile:FindFirstChild("R")
    local ready=false
    local resets=true
    local resetRetries=0
    local resetAt=0
    local barTween,cameraTween,flashTween
    local cameraOriginal,cameraOwned
    local releaseTicket
    local flashTweens={}
    local flashEnds=0
    local function endLocalVisuals()
        releaseTicket=nil
        if cameraTween then cameraTween:Cancel();cameraTween=nil end
        if cameraOwned and cameraOriginal then pcall(function() cameraOwned.FieldOfView=cameraOriginal end) end
        if flashTween then flashTween:Cancel();flashTween=nil end
        for _,tween in ipairs(flashTweens) do tween:Cancel() end;flashTweens={}
        if white then white.Visible=false end
        ready=false
        if label then label.Visible=false end
        if button then button.Visible=false end
    end
    local function updateHUD(state)
        if not state or state.character~=player.Character then return end
        local active=state.pairVictim~=nil or state.pairActor~=nil
        if meter then meter.Enabled=true end
        if bar then
            if barTween then barTween:Cancel() end
            barTween=ts:Create(bar,TweenInfo.new(0.15,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(1,0,state.funMeter or 0,0)});barTween:Play()
        end
        local threshold=({[1]=0.28,[2]=0.62,[3]=1})[state.pairPhase]
        ready=state.pairVictim~=nil and not state.pairReleasing and threshold~=nil and (state.funMeter or 0)>=threshold-0.000001
        if label then
            label.Visible=ready;label.Text=state.pairPhase==3 and "R - RELEASE" or "R - Faster"
            label.TextTransparency=0;label.TextStrokeTransparency=0
            local image=label:FindFirstChild("ImageLabel");if image then image.ImageTransparency=ready and 0.6 or 1 end
        end
        if button then button.Visible=ready end
        if resets==active then resets=not active;resetRetries=0;resetAt=0 end
    end
    local lastInput=0
    local function request()
        if ready and tick()-lastInput>=0.2 then lastInput=tick();ctx.network:send("PairSpeed") end
    end
    local function pulse(finish)
        local camera=workspace.CurrentCamera
        if camera then
            if cameraTween then cameraTween:Cancel() end
            if cameraOwned and cameraOwned~=camera then cameraOriginal=nil end
            cameraOwned=camera;cameraOriginal=cameraOriginal or camera.FieldOfView
            camera.FieldOfView=cameraOriginal+20
            cameraTween=ts:Create(camera,TweenInfo.new(0.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{FieldOfView=cameraOriginal});cameraTween:Play()
        end
        ctx.audio:play({key="audio/Heartbeat"})
        if finish and white then
            white.Visible=true
            for _,object in ipairs(white:GetDescendants()) do
                if object:IsA("ImageLabel") then
                    object.ImageTransparency=0
                    local tween=ts:Create(object,TweenInfo.new(1),{ImageTransparency=1});tween:Play();flashTweens[#flashTweens+1]=tween
                end
            end
            white.ImageTransparency=0
            if flashTween then flashTween:Cancel() end
            flashTween=ts:Create(white,TweenInfo.new(1),{ImageTransparency=1});flashTween:Play()
            flashEnds=tick()+1
        end
    end
    scope:add(input.InputBegan:Connect(function(key,processed)
        if not processed and not input:GetFocusedTextBox() and key.KeyCode==Enum.KeyCode.R then request() end
    end))
    if button then scope:add(button.Activated:Connect(request)) end
    scope:add(ctx.state:onChanged(function(state) module:apply(state);updateHUD(state) end))
    scope:add(ctx.network:on("Pair",function(data)
        if data.kind=="Clear" then
            clear(data.a);clear(data.v)
            if data.a==player.Character or data.v==player.Character then endLocalVisuals() end
        elseif data.kind=="Hit" and data.a==player.Character then ctx.gui:bumpHits()
        elseif data.kind=="Phase" and data.a==player.Character then
            pulse(data.phase==4)
            if data.phase==4 then
                local character=player.Character
                local ticket={victim=data.v};releaseTicket=ticket
                coroutine.wrap(function()
                    wait(3)
                    local state=ctx.state:localState()
                    if not scope.dead and releaseTicket==ticket and character==player.Character and state and state.pairReleasing and state.pairVictim==ticket.victim then pulse(true) end
                end)()
            end
        elseif data.kind=="Particles" then
            local h=handles[data.tag=="FD" and data.a or data.v]
            local fx=h and h.model:FindFirstChild("InteractionFX",true)
            if fx then
                local attachment=fx:FindFirstChild("Attachment")
                local blood=attachment and attachment:FindFirstChild("Blood")
                if blood then blood:Emit(data.n1) end
                local emitter=fx:FindFirstChildOfClass("ParticleEmitter");if emitter then emitter:Emit(data.n2) end
            end
        end
    end))
    scope:add(ctx.network:on("Remove",function(data)
        clear(data.character)
        if data.character==player.Character or (releaseTicket and data.character==releaseTicket.victim) then endLocalVisuals() end
    end))
    scope:add(player.CharacterRemoving:Connect(function(character)
        clear(character);endLocalVisuals();resets=true;resetRetries=0;resetAt=0
        if meter then meter.Enabled=false end
    end))
    scope:add(run.Heartbeat:Connect(function()
        if flashEnds>0 and tick()>=flashEnds then flashEnds=0;if white then white.Visible=false end end
        for character,p in pairs(pending) do
            local state=ctx.state:get(character)
            if not state or not character.Parent or tick()>=p.deadline then
                pending[character]=nil
                if state and character.Parent then ctx.report("Costume could not bind to R6 within 10 seconds: "..character.Name) end
            elseif character:FindFirstChild("Torso") and character:FindFirstChild("HumanoidRootPart") then module:apply(state) end
        end
        if resetRetries<25 and tick()>=resetAt then
            resetRetries=resetRetries+1;resetAt=tick()+0.1
            if pcall(function() starter:SetCore("ResetButtonCallback",resets) end) then resetRetries=25 end
        end
    end))
    scope:add(function()
        local chars={};for character in pairs(handles) do chars[#chars+1]=character end
        for _,character in ipairs(chars) do clear(character) end
        if barTween then barTween:Cancel() end;endLocalVisuals()
        pcall(function() starter:SetCore("ResetButtonCallback",true) end)
    end)
    function module:destroy() scope:destroy() end
    return module
end
