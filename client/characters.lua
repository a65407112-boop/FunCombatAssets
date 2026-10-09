-- Original R6 locomotion IDs, transitions and lean constants from Animate (6815)
-- and Leaning (6836). Combat pose playback has priority. No gameplay state is
-- changed here, and no second character rig is created.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local run = game:GetService("RunService")
    local player = game:GetService("Players").LocalPlayer
    local definitions = ctx.json("assets/animations/locomotion.json")
    local figures = {}
    local module = {}
    local function moodId(character)
        local ok,value=pcall(function() return character:GetAttribute("0e807e2b2887") end)
        return ok and type(value)=="number" and value>0 and value or 0
    end
    local function trackId(track)
        local ok,value=pcall(function() return track.Animation.AnimationId end)
        if not ok or type(value)~="string" then return 0 end
        return tonumber(value:match("id=(%d+)") or value:match("(%d+)$")) or 0
    end
    local function stopMood(record)
        if record.moodOwned and record.moodTrack then
            pcall(function() record.moodTrack:Stop(0.1);record.moodTrack:Destroy() end)
        end
        if record.moodAnimation then record.moodAnimation:Destroy() end
        record.moodTrack,record.moodAnimation,record.moodOwned=nil,nil,nil
    end
    local function updateMood(record)
        local head=record.character:FindFirstChild("Head")
        local id=moodId(record.character)
        if not head or not head:FindFirstChildOfClass("FaceControls") or id==0 then stopMood(record);return end
        -- Reuse an engine-owned mood. The runtime must not stop or duplicate
        -- it merely because it owns the source R6 body animation controller.
        local existing
        pcall(function()
            for _,track in ipairs(record.humanoid:GetPlayingAnimationTracks()) do
                if trackId(track)==id and not (record.moodOwned and track==record.moodTrack) then existing=track;break end
            end
        end)
        if existing then
            if record.moodTrack~=existing then stopMood(record) end
            record.moodHead,record.moodId,record.moodTrack=head,id,existing
            return
        end
        -- An engine track that has stopped no longer supplies the facial pose.
        -- Release its reference without stopping/destroying the native track.
        if record.moodTrack and not record.moodOwned then stopMood(record) end
        if record.moodTrack and record.moodHead==head and record.moodId==id then return end
        stopMood(record)
        if record.failedMoodHead==head and record.failedMoodId==id then return end
        record.moodHead,record.moodId=head,id
        local animation=Instance.new("Animation")
        animation.Name,animation.AnimationId="FunCombatOriginalMood","rbxassetid://"..id
        local ok,track=pcall(function() return record.humanoid:LoadAnimation(animation) end)
        if not ok then
            animation:Destroy();record.failedMoodHead,record.failedMoodId=head,id
            ctx.report("Original facial mood unavailable: rbxassetid://"..id..": "..tostring(track));return
        end
        record.moodTrack,record.moodAnimation,record.moodOwned=track,animation,true
        track.Priority,track.Looped=Enum.AnimationPriority.Core,true
        track:Play(0.1)
    end
    local function stop(record)
        if record.track then
            if record.trackOwned ~= false then
                pcall(function() record.track:Stop(0.1); record.track:Destroy() end)
            end
            record.track = nil
        end
        record.trackOwned = nil
        if record.keyframe then record.keyframe:Disconnect(); record.keyframe = nil end
        record.mode = nil
    end
    local function isLocomotionTrack(record, track)
        local ok, id = pcall(function() return track.Animation.AnimationId end)
        return ok and (record.locomotionIds[id] == true or record.locomotionIds[trackId(track)] == true)
    end
    local function replicatedGait(record)
        if not record.remote then return end
        local ok, tracks = pcall(function() return record.humanoid:GetPlayingAnimationTracks() end)
        if not ok then return end
        for _, track in ipairs(tracks) do
            if not (record.trackOwned and track == record.track) and track.IsPlaying ~= false
                and isLocomotionTrack(record, track) then return track end
        end
    end
    local function play(record, mode, transition, speed)
        -- The owner's server-created Animator already replicates native gait.
        -- Observe that track without changing its speed, phase or lifecycle.
        -- NPCs and a not-yet-arrived owner track retain the existing fallback.
        local native = replicatedGait(record)
        if native then
            if record.track ~= native then
                stop(record)
                record.track, record.trackOwned = native, false
            end
            record.mode = mode
            return
        end
        if record.trackOwned == false then stop(record) end
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
        record.track, record.mode, record.trackOwned = track, mode, true
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
            animations = {}, locomotionIds = {}, remote = character ~= player.Character,
            pose = "Standing", speed = 0, jumpUntil = 0, animate = {}}
        figures[character] = record
        for path, entry in pairs(definitions) do
            local mode = path:match("^([^/]+)/")
            if mode and entry.AnimationId and entry.AnimationId ~= "rbxassetid://0" then
                local animation = localScope:add(Instance.new("Animation"))
                animation.Name, animation.AnimationId = entry.Name, entry.AnimationId
                record.locomotionIds[entry.AnimationId] = true
                local id = trackId({Animation=animation})
                if id > 0 then record.locomotionIds[id] = true end
                record.animations[mode] = record.animations[mode] or {}
                table.insert(record.animations[mode], {instance = animation, weight = entry.weight or 1})
            end
        end
        local function disableDefault(child)
            if child:IsA("LocalScript") and child.Name == "Animate" and record.animate[child] == nil then
                if child:GetAttribute("0bc3bbc6f0b3")==true then return end
                record.animate[child] = child.Disabled
                child.Disabled = true
            end
        end
        for _, child in ipairs(character:GetChildren()) do disableDefault(child) end
        localScope:add(character.ChildAdded:Connect(disableDefault))
        pcall(function()
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                if not ctx.animations:ownsTrack(track)
                    and not (record.remote and isLocomotionTrack(record,track))
                    and not (moodId(character)>0 and trackId(track)==moodId(character)) then track:Stop(0.1) end
            end
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
            stopMood(record)
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
                if tick()>=(record.moodRefresh or 0) then
                    record.moodRefresh=tick()+0.5
                    updateMood(record)
                end
                local locked = state.downed or state.ragdolled or state.stunned or state.carriedBy or ctx.animations:blocksLocomotion(character)
                if locked or record.humanoid.Health <= 0 then stop(record)
                else
                    -- Running may not fire again when a carry/physics lock ends,
                    -- and remote server-owned characters can keep a stale speed.
                    -- Resume the source gait from actual horizontal movement.
                    if record.pose == "Standing" or record.pose == "Running" then
                        local velocity = record.root.Velocity
                        record.speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                        record.pose = record.speed > 0.01 and "Running" or "Standing"
                    end
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
                        local movement = record.humanoid.MoveDirection
                        if record.remote then
                            local velocity = record.root.Velocity
                            local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
                            movement = horizontal.Magnitude > 0.01 and horizontal.Unit or Vector3.new()
                        end
                        local direction = record.root.CFrame:VectorToObjectSpace(movement)
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
