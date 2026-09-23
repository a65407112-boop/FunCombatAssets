return function(ctx)
    local scope = ctx.cleanup:scope()
    local players = game:GetService("Players")
    local module = {}
    local function stateAnimation(state)
        if state.animation then
            local data = {}
            for k, v in pairs(state.animation) do data[k] = v end
            data.character = state.character
            ctx.animations:play(data)
        elseif state.animationRevision or state.downed or state.ragdolled or not state.character.Parent then
            ctx.animations:stop(state.character, state.animationRevision)
        end
    end
    scope:add(ctx.state:onChanged(stateAnimation))
    local snapshot = ctx.network:snapshot()
    ctx.state:apply(snapshot)
    for _, state in pairs(ctx.state:all()) do stateAnimation(state) end
    if snapshot.voting then ctx.network:dispatch("Voting", snapshot.voting) end
    if snapshot.weather then
        ctx.network:dispatch("Weather", type(snapshot.weather) == "table" and snapshot.weather or {name = snapshot.weather})
    end
    -- ContentProvider checks hosted references without making gameplay trust
    -- local assets. Failures name the content; they cannot freeze bootstrap.
    local alive = true
    scope:add(function() alive = false end)
    coroutine.wrap(function()
        local content = {}
        for _, root in pairs(ctx.assets.cache) do
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("Sound") or object:IsA("SpecialMesh") or object:IsA("Decal") or object:IsA("ImageLabel") or object:IsA("ImageButton") then content[#content + 1] = object end
            end
        end
        if #content > 0 and alive then
            local ok, why = pcall(function()
                game:GetService("ContentProvider"):PreloadAsync(content, function(asset, status)
                    if alive and tostring(status):find("Failure") then ctx.report("Hosted content unavailable: " .. tostring(asset)) end
                end)
            end)
            if not ok and alive then ctx.report("Hosted content validation: " .. tostring(why)) end
        end
    end)()
    scope:add(players.PlayerRemoving:Connect(function(player)
        if player.Character then ctx.animations:stop(player.Character) end
    end))
    function module:destroy() scope:destroy() end
    return module
end
