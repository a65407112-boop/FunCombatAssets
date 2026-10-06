-- Original Admin GUI; the server checks creator/configured-owner access on every command.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local input = game:GetService("UserInputService")
    local run = game:GetService("RunService")
    local tweens = game:GetService("TweenService")
    local allowed, loading, panelScope = false, false, nil
    local module = {}
    local function find(root, name) return root and root:FindFirstChild(name, true) end
    local function show()
        if not allowed or scope.dead or loading or panelScope then return end
        loading = true
        local ok, root = pcall(function() return ctx.assets:clone("gui/Admin") end)
        loading = false
        if not ok then ctx.report("Admin GUI could not load: " .. tostring(root)); return end
        if not allowed or scope.dead then root:Destroy(); return end
        local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
        if not pg or not allowed or scope.dead then root:Destroy(); return end
        local owner = scope:scope()
        panelScope = owner
        owner:add(root)
        owner:add(function() if panelScope == owner then panelScope = nil end end)
        root.ResetOnSpawn, root.Parent = false, pg
        local window = root:FindFirstChild("Frame")
        local profile = window and window:FindFirstChild("ProfileFrame")
        local commands = window and window:FindFirstChild("CommandFrame")
        if not window or not profile or not commands then
            ctx.report("Original Admin GUI is missing Frame/ProfileFrame/CommandFrame")
            owner:destroy(); return
        end
        local function bind(button, callback)
            if button and button:IsA("GuiButton") then
                owner:add(button.Activated:Connect(function()
                    if allowed and not owner.dead then callback() end
                end))
            end
        end
        bind(root:FindFirstChild("TextButton"), function() window.Visible = not window.Visible end)
        for _, page in ipairs({profile, commands}) do
            local inner = page:FindFirstChild("Frame")
            bind(inner and inner:FindFirstChild("ImageButton"), function() window.Visible = false end)
            local tabs = find(page, "etcframe")
            bind(find(tabs, "1"), function() profile.Visible, commands.Visible = true, false end)
            bind(find(tabs, "2"), function() profile.Visible, commands.Visible = false, true end)
            for _, button in ipairs(page:GetDescendants()) do
                local command = button.Name
                if button:IsA("GuiButton") and button.Parent:IsA("TextBox")
                    and (command == "Kick" or command == "Kill" or command == "NoRespawn") then
                    bind(button, function()
                        ctx.network:send("Admin", {command=command, target=button.Parent.Text})
                    end)
                end
            end
        end
        local container = find(profile, "Container")
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("TextLabel") and item.Text == "OnlyTwentyCharacters" then item.Text = player.Name end
            end
        end
        local info = find(profile, "InfoContainer")
        local card = info and info.Parent
        local uptime = info and info:FindFirstChild("ServerUpTime")
        local count = info and info:FindFirstChild("TextLabel")
        local date = card and card:FindFirstChild("TextLabel")
        local avatar = card and card:FindFirstChild("ImageLabel")
        local function refresh()
            local elapsed = math.floor(tonumber(workspace.DistributedGameTime) or 0)
            if uptime then uptime.Text = "Server UpTime: " .. math.floor(elapsed/3600)
                .. "h - " .. math.floor(elapsed/60)%60 .. "m - " .. elapsed%60 .. "s" end
            if count then count.Text = "Players in Server: " .. #players:GetPlayers() end
            if date then date.Text = os.date("%x") end
        end
        refresh()
        local elapsed = 0
        owner:add(run.Heartbeat:Connect(function(dt)
            elapsed = elapsed + (dt or 0)
            if elapsed >= 1 then elapsed = 0; refresh() end
        end))
        if avatar then
            coroutine.wrap(function()
                local loaded, url = pcall(function()
                    return players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                end)
                if not owner.dead and avatar.Parent and loaded then avatar.Image = url end
            end)()
        end
        local pointer, startInput, startPosition, tween
        owner:add(function() if tween then tween:Cancel() end end)
        owner:add(window.InputBegan:Connect(function(event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
                pointer, startInput, startPosition = event, event.Position, window.Position
            end
        end))
        owner:add(input.InputChanged:Connect(function(event)
            if not pointer or (event.UserInputType ~= Enum.UserInputType.MouseMovement and event ~= pointer) then return end
            local delta = event.Position - startInput
            if tween then tween:Cancel() end
            tween = tweens:Create(window, TweenInfo.new(0.25), {Position=UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset+delta.X, startPosition.Y.Scale, startPosition.Y.Offset+delta.Y)})
            tween:Play()
        end))
        owner:add(input.InputEnded:Connect(function(event)
            if event == pointer or (pointer and event.UserInputType == Enum.UserInputType.MouseButton1) then pointer = nil end
        end))
    end
    scope:add(ctx.network:on("Admin", function(data)
        if type(data) ~= "table" then return end
        allowed = data.allowed == true
        if not allowed and panelScope then panelScope:destroy() end
        if data.error then ctx.report("Admin: " .. tostring(data.error)) end
        if data.creator and data.creator.error then ctx.report("Creator access: "..tostring(data.creator.error)) end
        if data.kohl and data.kohl.error then ctx.report("Original Kohl's Admin: "..tostring(data.kohl.error)) end
        show()
    end))
    function module:destroy() scope:destroy() end
    return module
end
