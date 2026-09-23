return function(ctx)
    local scope = ctx.cleanup:scope()
    local runService = game:GetService("RunService")
    local soundService = game:GetService("SoundService")
    local playing = {}
    local removed = setmetatable({}, {__mode = "k"})
    local warned = {}
    local alive = true
    local module = {}

    local function report(key, message)
        if not warned[key] then warned[key] = true; ctx.report(message) end
    end

    local function finite(value, default)
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return default end
        return value
    end

    local function cloneSound(data)
        if data.sound and typeof(data.sound) == "Instance" and data.sound:IsA("Sound") then
            return data.sound:Clone()
        end
        local key = data.key
        if type(key) ~= "string" then return nil end
        if ctx.catalog.packages[key] then return ctx.assets:clone(key) end
        local name = string.match(key, "^weapons/.-/audio/(.+)$") or string.match(key, "^weapon/(.+)$")
        if name and ctx.weapons then
            local original = ctx.weapons:getSound(data.character, name)
            if original then return original:Clone() end
        end
        if ctx.catalog.packages["audio/" .. key] then return ctx.assets:clone("audio/" .. key) end
        return nil
    end

    function module:play(data)
        if not alive or scope.dead or type(data) ~= "table" or (data.character and removed[data.character]) then return nil end
        local ok, sound = pcall(cloneSound, data)
        if not ok or typeof(sound) ~= "Instance" or not sound:IsA("Sound") then
            if sound and typeof(sound) == "Instance" then sound:Destroy() end
            report(tostring(data.key), "Original sound could not load: " .. tostring(data.key))
            return nil
        end
        if not alive or scope.dead or (data.character and (removed[data.character] or not data.character.Parent)) then sound:Destroy(); return nil end
        local childScope = scope:scope()
        childScope:add(sound)
        local character = data.character
        local parent = data.parent
        if not parent and character then parent = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") end
        if character and not parent then childScope:destroy(); return nil end
        sound.PlayOnRemove = false
        sound.PlaybackSpeed = math.max(0.1, math.min(4, finite(data.speed, sound.PlaybackSpeed)))
        if data.start then sound.TimePosition = math.max(0, finite(data.start, 0)) end
        sound.Parent = parent or soundService
        local now = tick()
        local duration = finite(data.duration, nil)
        if duration then duration = math.max(0.05, math.min(120, duration)) end
        local entry = {sound = sound, scope = childScope, character = character, started = now,
            deadline = now + (duration or 20), explicit = duration ~= nil, loaded = false}
        playing[sound] = entry
        local function finish()
            if playing[sound] then playing[sound] = nil; childScope:destroy() end
        end
        childScope:add(sound.Ended:Connect(finish))
        childScope:add(function() playing[sound] = nil end)
        sound:Play()
        return sound
    end

    function module:stop(character)
        local remove = {}
        for _, entry in pairs(playing) do
            if entry.character == character then remove[#remove + 1] = entry end
        end
        for _, entry in ipairs(remove) do entry.scope:destroy() end
    end

    scope:add(runService.Heartbeat:Connect(function()
        local now = tick()
        local remove = {}
        for _, entry in pairs(playing) do
            local sound = entry.sound
            if sound.IsLoaded and not entry.loaded then
                entry.loaded = true
                if not entry.explicit then
                    entry.deadline = now + math.max(1, math.min(120, sound.TimeLength / sound.PlaybackSpeed + 1))
                end
            end
            if now >= entry.deadline or not sound.Parent or (entry.character and not entry.character.Parent) then
                if not entry.loaded then report(sound.SoundId, "Original audio did not load: " .. sound.SoundId) end
                remove[#remove + 1] = entry
            end
        end
        for _, entry in ipairs(remove) do entry.scope:destroy() end
    end))
    scope:add(ctx.network:on("Sound", function(data) module:play(data) end))
    scope:add(ctx.network:on("Remove", function(data)
        if data and data.character then removed[data.character] = true; module:stop(data.character) end
    end))
    scope:add(function() alive = false end)
    function module:destroy() scope:destroy() end
    return module
end
