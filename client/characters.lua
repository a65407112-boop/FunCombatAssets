-- Original R6 locomotion IDs, transitions and lean constants from Animate (6815)
-- and Leaning (6836). Combat pose playback has priority. No gameplay state is
-- changed here, and no second character rig is created.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local run = game:GetService("RunService")
    local definitions = ctx.json("assets/animations/locomotion.json")
    local figures = {}
    local module = {}
    local function stop(record)
        if record.track then
            pcall(function() record.track:Stop(0.1); record.track:Destroy() end)
            record.track = nil
        end
        if record.keyframe then record.keyframe:Disconnect(); record.keyframe = nil end
        record.mode = nil
    end
    local function play(record, mode, transition, speed)
        if record.mode == mode and record.track then
            if speed then record.track:AdjustSpeed(speed) end
            return
        end
        stop(record)
        if record.failedMode == mode and tick() < record.retryAt then return end
        local choices = record.animations[mode]
        if not choices then return end
        local total = 0
        for _, choice in ipairs(choices) do total = total + choice.weight end
        local pick = math.random() * total
        local selected = choices[1]
        for _, choice in ipairs(choices) do
            pick = pick - choice.weight
            if pick <= 0 then selected = choice; break end
        end
        local ok, track = pcall(function() return record.humanoid:LoadAnimation(selected.instance) end)
        if not ok then
            record.failedMode, record.retryAt = mode, tick() + 5
            ctx.report("Original locomotion unavailable: " .. selected.instance.AnimationId .. ": " .. tostring(track)); return
        end
        record.track, record.mode = track, mode
        track.Priority = Enum.AnimationPriority.Core
        track:Play(transition or 0.1)
        if speed then track:AdjustSpeed(speed) end
        record.keyframe = track.KeyframeReached:Connect(function(name)
            if name == "End" and record.track == track then
                record.mode = nil
            end
        end)
    end
    local function remove(character)
        local record = figures[character]
        if record then figures[character] = nil; record.scope:destroy() end
    end
    local function attach(character)
        if figures[character] or not character.Parent then return figures[character] end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        local torso = character:FindFirstChild("Torso")
        if not humanoid or not root or not torso then return end
        local localScope = scope:scope()
        local record = {character = character, humanoid = humanoid, root = root, scope = localScope,
            animations = {}, pose = "Standing", speed = 0, jumpUntil = 0, animate = {}}
        figures[character] = record
        for path, entry in pairs(definitions) do
            local mode = path:match("^([^/]+)/")
            if mode and entry.AnimationId and entry.AnimationId ~= "rbxassetid://0" then
                local animation = localScope:add(Instance.new("Animation"))
                animation.Name, animation.AnimationId = entry.Name, entry.AnimationId
                record.animations[mode] = record.animations[mode] or {}
                table.insert(record.animations[mode], {instance = animation, weight = entry.weight or 1})
            end
        end
        local function disableDefault(child)
            if child:IsA("LocalScript") and child.Name == "Animate" and record.animate[child] == nil then
                record.animate[child] = child.Disabled
                child.Disabled = true
            end
        end
        for _, child in ipairs(character:GetChildren()) do disableDefault(child) end
        localScope:add(character.ChildAdded:Connect(disableDefault))
        pcall(function()
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do track:Stop(0.1) end
        end)
        localScope:add(humanoid.Running:Connect(function(speed) record.speed = speed; record.pose = speed > 0.01 and "Running" or "Standing" end))
        localScope:add(humanoid.Jumping:Connect(function(active) if active then record.pose = "Jumping"; record.jumpUntil = tick() + 0.3 end end))
        localScope:add(humanoid.Climbing:Connect(function(speed) record.pose = "Climbing"; record.speed = speed end))
        localScope:add(humanoid.FreeFalling:Connect(function(active) if active then record.pose = "FreeFall" end end))
        localScope:add(humanoid.Seated:Connect(function(active) record.pose = active and "Seated" or "Standing" end))
        localScope:add(humanoid.Swimming:Connect(function(speed) record.pose = speed > 0 and "Running" or "Standing"; record.speed = speed end))
        localScope:add(humanoid.Died:Connect(function() stop(record) end))
        localScope:add(character.AncestryChanged:Connect(function() if not character.Parent then remove(character) end end))
        record.joint = root:FindFirstChild("RootJoint")
        if record.joint then record.original = record.joint.C0 end
        localScope:add(function()
            stop(record)
            if record.joint and record.joint.Parent then record.joint.C0 = record.original end
            for script, disabled in pairs(record.animate) do
                if script.Parent then pcall(function() script.Disabled = disabled end) end
            end
        end)
        return record
    end
    scope:add(ctx.state:onChanged(function(state) attach(state.character) end))
    scope:add(ctx.network:on("Remove", function(data) remove(data.character) end))
    scope:add(run.Heartbeat:Connect(function(dt)
        for character, state in pairs(ctx.state:all()) do
            local record = figures[character] or attach(character)
            if record then
                local locked = state.downed or state.ragdolled or state.stunned or state.carrying or state.carriedBy or ctx.animations:isPlaying(character)
                if locked or record.humanoid.Health <= 0 then stop(record)
                else
                    local mode, transition, speed = "idle", 0.1, 1
                    if record.pose == "Jumping" and tick() < record.jumpUntil then mode = "jump"
                    elseif record.pose == "FreeFall" then
                        mode = tick() < record.jumpUntil and "jump" or "fall"; transition = 0.3
                    elseif record.pose == "Running" then mode = "walk"; speed = record.speed / 14.5
                    elseif record.pose == "Climbing" then mode = "climb"; speed = record.speed / 12
                    elseif record.pose == "Seated" then mode = "sit"; transition = 0.5 end
                    play(record, mode, transition, speed)
                end
                if record.joint and record.joint.Parent then
                    if locked then record.joint.C0 = record.original
                    else
                        local direction = record.root.CFrame:VectorToObjectSpace(record.humanoid.MoveDirection)
                        -- Original MIN_MOMENTUM == MAX_MOMENTUM == .13.
                        local x, z = direction.X * 0.13, direction.Z * 0.13 / 2
                        record.joint.C0 = record.joint.C0:Lerp(record.original * CFrame.Angles(-z, -x, 0), math.min(1, dt * 7))
                    end
                end
            end
        end
    end))
    function module:destroy() scope:destroy(); figures = {} end
    return module
end
