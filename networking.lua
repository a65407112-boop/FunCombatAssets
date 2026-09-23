return function(ctx)
    local scope = ctx.cleanup:scope()
    local listeners = {}
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
    assert(version.Value == 2, "Incompatible Fun Combat protocol version")
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
        if type(kind) == "string" and type(data) == "table" then module:dispatch(kind, data) end
    end))
    function module:send(name, payload)
        if not ctx.cleanup.dead then action:FireServer(name, payload) end
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
        assert(type(result) == "table" and result.version == 2 and type(result.states) == "table", "Invalid server snapshot")
        self.serverOffset = (result.serverTime or tick()) - (sentAt + tick()) / 2
        return result
    end
    function module:now() return tick() + (self.serverOffset or 0) end
    function module:destroy() scope:destroy(); listeners = {} end
    return module
end
