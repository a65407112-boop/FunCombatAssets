return function(ctx)
    local scope = ctx.cleanup:scope()
    local listeners = {}
    local ACTION_WIRE = {Equip="3c671a374c1f", Swing="805192fe6ae8", Dash="c2e93057f5b3", GetUp="938f5b0c32ab", Emote="cabfea65c343", Vote="775c1e818b78", Drop="b2bcf069c718", Gender="7fdcd3043c35", Admin="61e9b8552b9d"}
    local PRESENTATION_LOGICAL = {ae8f20f5496d="State", d698ecef3426="Animation", ["48bcd6935413"]="StopAnimation", ["0fed684c4df0"]="Sound", ["79d35804b662"]="Effect", ["9246128df0fc"]="Damage", ["14106736b859"]="Subtitle", ["2cdf15cd69f1"]="Awaken", ["6be4abcedd5c"]="Voting", ["3a1a93f5a213"]="Weather", ["61e9b8552b9d"]="Admin", ["66157b66fb8b"]="Remove"}
    local rs = game:GetService("ReplicatedStorage")
    local function find(parent, name, class)
        local stop = tick() + 15
        repeat
            local child = parent:FindFirstChild(name)
            if child then
                assert(child:IsA(class), "Wrong server protocol class for " .. name)
                return child
            end
            wait(0.05)
        until tick() >= stop or ctx.cleanup.dead
        error("Expected Fun Combat server protocol is unavailable: " .. name .. " (15-second timeout)")
    end
    local folder = find(rs, "Remotes", "Folder")
    local action = find(folder, "Action", "RemoteEvent")
    local event = find(folder, "Presentation", "RemoteEvent")
    local snapshot = find(folder, "Snapshot", "RemoteFunction")
    local version = find(folder, "Version", "IntValue")
    assert(version.Value == 4, "Fun Combat requires the matching protocol 4 server place; update Game_Server.rbxlx")
    local module = {}
    function module:on(kind, callback)
        listeners[kind] = listeners[kind] or {}
        local group = listeners[kind]; group[callback] = true
        return function() group[callback] = nil end
    end
    function module:dispatch(kind, data)
        for callback in pairs(listeners[kind] or {}) do
            local ok, err = pcall(callback, data)
            if not ok then ctx.report("Presentation " .. tostring(kind) .. ": " .. tostring(err)) end
        end
    end
    scope:add(event.OnClientEvent:Connect(function(kind, data)
        local logical = type(kind) == "string" and PRESENTATION_LOGICAL[kind] or nil
        if logical and type(data) == "table" then module:dispatch(logical, data) end
    end))
    function module:send(name, payload)
        if not ctx.cleanup.dead then local encoded = ACTION_WIRE[name]
        assert(encoded, "Unknown Fun Combat action: " .. tostring(name))
        action:FireServer(encoded, payload) end
    end
    function module:snapshot()
        local sentAt = tick()
        local done, result, failure = false, nil, nil
        coroutine.wrap(function()
            local ok, data = pcall(function() return snapshot:InvokeServer() end)
            if ok then result = data else failure = data end
            done = true
        end)()
        local deadline = tick() + 15
        repeat wait(0.05) until done or tick() >= deadline or ctx.cleanup.dead
        assert(done and not failure, "Server snapshot failed or timed out: " .. tostring(failure))
        assert(type(result) == "table" and result.version == 4 and type(result.states) == "table", "Invalid server snapshot")
        self.serverOffset = (result.serverTime or tick()) - (sentAt + tick()) / 2
        return result
    end
    function module:now() return tick() + (self.serverOffset or 0) end
    function module:destroy() scope:destroy(); listeners = {} end
    return module
end
