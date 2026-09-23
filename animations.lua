-- Plays original stored Pose.CFrame values; no animation upload or asset ID is
-- required for combat sequences. Source-clock mode reproduces the source
-- AnimationPlayer's per-keyframe timing at its nominal 60 Hz update rate.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local cache, active, pending = {}, {}, {}
    local revisions = setmetatable({}, {__mode = "k"})
    local run = game:GetService("RunService")
    local module = {}
    local function originalSpeed(key)
        if key == "bat/gripAttacker" or key == "bat/gripVictim" or key == "bat/finishHoldAttacker" or key == "bat/finishHoldVictim" then return 250 end
        return 50
    end
    local function getSequence(key)
        if cache[key] then return cache[key] end
        local item = assert(ctx.catalog.animations[key], "Unknown original animation: " .. tostring(key))
        local raw = ctx.json(item.path)
        assert(#raw.frames > 0, "Empty keyframe data: " .. key)
        local timeline, elapsed = {}, 0
        for _, frame in ipairs(raw.frames) do
            local time
            if ctx.config.AnimationClock == "keyframes" then time = frame.time
            else
                elapsed = elapsed + math.max(1, math.ceil(frame.time / originalSpeed(key) * 60 - 0.00001)) / 60
                time = elapsed
            end
            for _, pose in ipairs(frame.poses) do
                if pose.parent then
                    local jointKey = pose.parent .. "\0" .. pose.name
                    timeline[jointKey] = timeline[jointKey] or {}
                    local curve = timeline[jointKey]
                    local weight = ctx.config.AnimationClock == "keyframes" and (pose.weight or 1) or 1
                    curve[#curve + 1] = {time = time, value = CFrame.new(unpack(pose.cframe)), weight = weight}
                end
            end
        end
        local result = {curves = timeline, loop = raw.loop, duration = ctx.config.AnimationClock == "keyframes" and raw.duration or elapsed}
        cache[key] = result
        return result
    end
    local function findJoints(character)
        local joints = {}
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("Motor6D") and object.Part0 and object.Part1 and not object.Part1.Parent:IsA("Accessory") then
                joints[object.Part0.Name .. "\0" .. object.Part1.Name] = object
            end
        end
        return joints
    end
    function module:stop(character, revision)
        if not character then return end
        if revision and revision < (revisions[character] or 0) then return end
        if revision then revisions[character] = revision end
        pending[character] = nil
        local track = active[character]
        if not track then return end
        active[character] = nil
        for joint, initial in pairs(track.initial) do
            if joint.Parent then pcall(function() joint.Transform = initial end) end
        end
    end
    function module:isPlaying(character) return active[character] ~= nil end
    function module:play(data)
        local character = data.character
        if typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent then return end
        local revision = data.revision or 0
        if revision < (revisions[character] or 0) then return end
        revisions[character] = revision
        local previous = active[character]
        if previous and previous.key == data.key and previous.start == data.start then return end
        local ticket = {}
        pending[character] = ticket
        local ok, sequence = pcall(getSequence, data.key)
        if pending[character] ~= ticket or ctx.cleanup.dead then return end
        if not ok then ctx.report("Animation " .. tostring(data.key) .. ": " .. tostring(sequence)); return end
        local start = data.start or ctx.network:now()
        local speed = type(data.speed) == "number" and math.max(0.01, math.min(8, data.speed)) or 1
        local loop = data.loop
        if loop == nil then loop = sequence.loop end
        if not loop and (ctx.network:now() - start) * speed > sequence.duration then self:stop(character); return end
        self:stop(character)
        local joints = findJoints(character); local initial = {}
        for key, joint in pairs(joints) do if sequence.curves[key] then initial[joint] = joint.Transform end end
        active[character] = {key = data.key, sequence = sequence, start = start, speed = speed, loop = loop, joints = joints, initial = initial, refresh = 0}
    end
    local function sample(curve, at, initial)
        if at <= curve[1].time then
            local alpha = curve[1].time == 0 and 1 or math.max(0, at / curve[1].time)
            return initial:Lerp(curve[1].value, alpha * curve[1].weight)
        end
        local low, high = 1, #curve
        while low < high do
            local middle = math.floor((low + high + 1) / 2)
            if curve[middle].time <= at then low = middle else high = middle - 1 end
        end
        local a, b = curve[low], curve[low + 1]
        if not b then return a.value end
        local alpha = math.min(1, math.max(0, (at - a.time) / math.max(0.000001, b.time - a.time)))
        return a.value:Lerp(b.value, alpha * b.weight)
    end
    scope:add(run.Stepped:Connect(function()
        local now = ctx.network:now()
        for character, track in pairs(active) do
            local elapsed = math.max(0, (now - track.start) * track.speed)
            local duration = track.sequence.duration
            if not character.Parent or (not track.loop and elapsed > duration) then module:stop(character)
            else
                if track.loop and duration > 0 then elapsed = elapsed % duration end
                if now >= track.refresh then
                    track.refresh = now + 0.1
                    track.joints = findJoints(character)
                    for key, joint in pairs(track.joints) do
                        if track.sequence.curves[key] and not track.initial[joint] then track.initial[joint] = joint.Transform end
                    end
                end
                for key, curve in pairs(track.sequence.curves) do
                    local joint = track.joints[key]
                    if joint and joint.Parent and joint.Enabled then
                        joint.Transform = sample(curve, elapsed, track.initial[joint] or CFrame.new())
                    end
                end
            end
        end
    end))
    scope:add(ctx.network:on("Animation", function(data) module:play(data) end))
    scope:add(ctx.network:on("StopAnimation", function(data) module:stop(data.character, data.revision) end))
    scope:add(ctx.network:on("Remove", function(data) module:stop(data.character) end))
    scope:add(function()
        local characters = {}; for character in pairs(active) do characters[#characters + 1] = character end
        for _, character in ipairs(characters) do module:stop(character) end
        cache, pending = {}, {}
    end)
    function module:destroy() scope:destroy() end
    return module
end
