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
