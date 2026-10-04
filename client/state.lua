return function(ctx)
    local values, listeners = {}, {}
    local removed = setmetatable({}, {__mode = "k"})
    local scope = ctx.cleanup:scope()
    local module = {}
    function module:update(state)
        if type(state) ~= "table" or typeof(state.character) ~= "Instance" then return end
        if removed[state.character] then return end
        local previous = values[state.character]
        if previous and (state.revision or 0) <= (previous.revision or -1) then return end
        values[state.character] = state
        for callback in pairs(listeners) do
            local ok, err = pcall(callback, state, previous)
            if not ok then ctx.report("State presentation: " .. tostring(err)) end
        end
    end
    function module:apply(snapshot)
        local present={}
        for _,state in pairs(snapshot.states) do if state.character then present[state.character]=true end end
        local absent={}
        for character,state in pairs(values) do
            if not present[character] and (state.serverTime or 0)<=(snapshot.serverTime or math.huge) then absent[#absent+1]=character end
        end
        for _,character in ipairs(absent) do ctx.network:dispatch("Remove",{character=character}) end
        for _, state in pairs(snapshot.states) do self:update(state) end
    end
    function module:onChanged(callback)
        listeners[callback] = true
        return function() listeners[callback] = nil end
    end
    function module:get(character) return values[character] end
    function module:all() return values end
    function module:localState() return values[game:GetService("Players").LocalPlayer.Character] end
    scope:add(ctx.network:on("State", function(state) module:update(state) end))
    scope:add(ctx.network:on("Remove", function(data)
        if data.character then values[data.character] = nil; removed[data.character] = true end
    end))
    scope:add(function() values = {}; listeners = {} end)
    function module:destroy() scope:destroy() end
    return module
end
