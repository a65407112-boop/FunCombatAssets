-- One input owner. No hit targets, damage values, or client physics are sent.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local players = game:GetService("Players")
    local inputService = game:GetService("UserInputService")
    local player = players.LocalPlayer
    local module = {}
    local alive = true
    local lastSent = {}
    local emoteKeys = {[Enum.KeyCode.G] = "1", [Enum.KeyCode.H] = "2", [Enum.KeyCode.J] = "3",
        [Enum.KeyCode.K] = "4", [Enum.KeyCode.L] = "5"}
    local weapons = {Bat = true, Sword = true, [":3"] = true, BoyKisser = true, Maxwell = true, ["Orange Cat"] = true, [""] = true}
    local mouse = player:GetMouse()
    local oldIcon = mouse.Icon
    local wroteIcon = false
    local ownIcon

    local function canAct(state)
        return state and state.character == player.Character and (state.health or 0) > 0
            and not state.downed and not state.ragdolled and not state.carriedBy
            and not state.busy and state.canAct ~= false
    end

    function module:request(action, payload)
        if not alive then return false end
        local state = ctx.state:localState()
        if action == "Vote" then
            if type(payload) ~= "string" then return false end
        elseif action == "GetUp" then
            if not state or not state.downed or not state.canGetUp or state.carriedBy then return false end
            payload = nil
        elseif action == "Drop" then
            if not state or not state.carrying then return false end
            payload = nil
        elseif action == "Swing" or action == "Dash" then
            if not canAct(state) or state.carrying or not weapons[state.weapon] or state.weapon == "" then return false end
            -- Source combo cooldowns may expire before the prior hitbox window.
            -- The server accepts that overlap and owns Swing/Dash timing.
            if action == "Dash" then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local direction = humanoid and humanoid.MoveDirection or Vector3.new()
                if direction.Magnitude < 0.01 and root then direction = root.CFrame.LookVector end
                payload = {direction = Vector3.new(direction.X, 0, direction.Z)}
            else
                payload = nil
            end
        elseif action == "Equip" then
            if not canAct(state) or state.carrying or not weapons[payload] then return false end
        elseif action == "Emote" then
            if not canAct(state) or state.carrying or state.attacking then return false end
            if payload ~= "Stop" and (type(payload) ~= "string" or not string.match(payload, "^[1-5]$")) then return false end
        else
            return false
        end
        -- Debounce accidental duplicate input only; the server owns real cooldowns.
        local now = tick()
        if now - (lastSent[action] or -math.huge) < 0.045 then return false end
        lastSent[action] = now
        ctx.network:send(action, payload)
        return true
    end

    scope:add(ctx.gui:onAction(function(action, payload) module:request(action, payload) end))
    scope:add(inputService.InputBegan:Connect(function(input, processed)
        if processed or inputService:GetFocusedTextBox() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            module:request("Swing")
        elseif input.KeyCode == Enum.KeyCode.Q then
            module:request("Dash")
        elseif input.KeyCode == Enum.KeyCode.G then
            local state = ctx.state:localState()
            if state and state.downed then module:request("GetUp") else module:request("Emote", "1") end
        elseif emoteKeys[input.KeyCode] then
            module:request("Emote", emoteKeys[input.KeyCode])
        elseif input.KeyCode == Enum.KeyCode.Backspace then
            local state = ctx.state:localState()
            if state and state.carrying then module:request("Drop") end
        end
    end))
    -- The original mobile GUI has Dash/GetUp only. An unconsumed world tap is Swing.
    scope:add(inputService.TouchTap:Connect(function(_, processed)
        if not processed and not inputService:GetFocusedTextBox() then module:request("Swing") end
    end))
    local function updateIcon(state)
        if not state or state.character ~= player.Character then return end
        if state.weapon and state.weapon ~= "" then
            ownIcon = state.attacking and "rbxasset://textures/GunWaitCursor.png" or "rbxasset://textures/GunCursor.png"
            mouse.Icon = ownIcon
            wroteIcon = true
        elseif wroteIcon then
            if mouse.Icon == ownIcon then mouse.Icon = oldIcon end
            wroteIcon = false
        end
    end
    scope:add(ctx.state:onChanged(updateIcon))
    scope:add(player.CharacterAdded:Connect(function()
        lastSent = {}
        if wroteIcon and mouse.Icon == ownIcon then mouse.Icon = oldIcon end
        wroteIcon = false
    end))
    scope:add(function()
        alive = false
        if wroteIcon and mouse.Icon == ownIcon then mouse.Icon = oldIcon end
    end)
    updateIcon(ctx.state:localState())
    function module:destroy() scope:destroy() end
    return module
end
