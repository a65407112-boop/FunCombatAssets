return function(ctx)
    local scope = ctx.cleanup:scope()
    local players = game:GetService("Players")
    local module = {}
    local function stateAnimation(state)
        ctx.pair:apply(state)
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
    if snapshot.admin then ctx.network:dispatch("Admin", snapshot.admin) end
    for _, state in pairs(ctx.state:all()) do stateAnimation(state) end
    if snapshot.voting then ctx.network:dispatch("Voting", snapshot.voting) end
    if snapshot.weather then
        ctx.network:dispatch("Weather", type(snapshot.weather) == "table" and snapshot.weather or {name = snapshot.weather})
    end
    ctx.network:activate(snapshot.serverTime)
    scope:add(ctx.network:on("Error",function(data) ctx.report("Server: "..tostring(data.text or "unspecified error")) end))
    scope:add(ctx.network:on("Notice",function(data)
        local root=ctx.gui.roots.yeah
        local label=root and root:FindFirstChild("TextLabel",true)
        if label then label.Text=tostring(data.text or "");root.Enabled=true end
        pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="Fun Combat",Text=tostring(data.text or ""),Duration=5}) end)
    end))
    local syncing=false
    local function synchronize()
        if syncing or scope.dead then return end
        syncing=true
        local ok,result=pcall(function() return ctx.network:snapshot() end)
        syncing=false
        if scope.dead then return end
        if ok then
            ctx.state:apply(result)
            if result.voting then ctx.network:dispatch("Voting",result.voting) end
            if result.weather then ctx.network:dispatch("Weather",result.weather) end
        else ctx.report("State refresh: "..tostring(result)) end
    end
    scope:add(players.LocalPlayer.CharacterAdded:Connect(function(character)
        coroutine.wrap(function()
            local deadline=tick()+10
            repeat wait(0.1) until scope.dead or character~=players.LocalPlayer.Character or character:FindFirstChild("Torso") or tick()>=deadline
            if not scope.dead and character==players.LocalPlayer.Character then synchronize() end
        end)()
    end))
    coroutine.wrap(function()
        while not scope.dead do wait(15);if not scope.dead then synchronize() end end
    end)()
    -- The preload dependency has already warmed the original presentation and
    -- bounded hosted-content loading before combat input was connected.
    scope:add(players.PlayerRemoving:Connect(function(player)
        if player.Character then ctx.animations:stop(player.Character) end
    end))
    function module:destroy() scope:destroy() end
    return module
end
