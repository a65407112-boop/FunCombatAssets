-- Original exported GUI trees, with a single dispatcher for safe action requests.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local players = game:GetService("Players")
    local inputService = game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local tweenService = game:GetService("TweenService")
    local lighting = game:GetService("Lighting")
    local player = players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui", 15)
    assert(playerGui, "PlayerGui did not become available")
    local roots = {}
    local listeners = {}
    local billboards = {}
    local tweens = {}
    local alive = true
    local localCharacter = player.Character
    local module = {roots = roots}
    local emoteNames = {"Boston Breakdance", "Flex", "Rat", "Akiyama", "idk"}
    local screenNames = {"HitboxToggle", "Shiftlock", "getUp", "mobileButtons", "title", "Subtitles",
        "Emotes", "awakenScreen", "MapVoteGui", "weapon", "weaponGui", "HitIndicator"}
    local warned = {}

    local function clone(key)
        if not ctx.catalog.packages[key] then return nil end
        local ok, result = pcall(function() return ctx.assets:clone(key) end)
        if ok and typeof(result) == "Instance" then
            if scope.dead then result:Destroy(); return nil end
            return result
        end
        if not warned[key] then warned[key] = true; ctx.report("GUI asset could not load: " .. key .. ": " .. tostring(result)) end
        return nil
    end
    local function find(root, name)
        return root and root:FindFirstChild(name, true) or nil
    end
    local function text(root, value)
        if root and (root:IsA("TextLabel") or root:IsA("TextButton")) then root.Text = tostring(value) end
    end
    local function emit(action, payload)
        for callback in pairs(listeners) do callback(action, payload) end
    end
    function module:onAction(callback)
        listeners[callback] = true
        return function() listeners[callback] = nil end
    end
    local function cancelTween(object)
        local previous = tweens[object]
        if previous then
            tweens[object] = nil
            previous.connection:Disconnect()
            previous.tween:Cancel()
        end
    end
    local function tween(object, duration, properties, style, direction)
        if not object then return end
        cancelTween(object)
        local animation = tweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Sine,
            direction or Enum.EasingDirection.InOut), properties)
        local entry = {tween = animation}
        tweens[object] = entry
        entry.connection = animation.Completed:Connect(function()
            entry.connection:Disconnect()
            if tweens[object] == entry then tweens[object] = nil end
        end)
        animation:Play()
    end
    local function sound(button)
        local press = find(button, "Press")
        if press and press:IsA("Sound") then ctx.audio:play({sound = press}) end
    end
    local function bind(button, callback, owner)
        if button and button:IsA("GuiButton") then
            (owner or scope):add(button.Activated:Connect(function()
                if alive then sound(button); callback() end
            end))
        end
    end

    for _, name in ipairs(screenNames) do
        local root = clone("gui/" .. name)
        if root then
            roots[name] = root
            scope:add(root)
            if root:IsA("ScreenGui") then root.ResetOnSpawn = false end
            root.Parent = playerGui
        end
    end
    for _, name in ipairs({"stats", "society"}) do
        roots[name] = clone("gui/" .. name)
        if roots[name] then
            roots[name].ResetOnSpawn = false
            scope:add(roots[name])
        end
    end
    local voteTemplate = clone("gui/MapFrame")
    if voteTemplate then scope:add(voteTemplate) end
    local awakeningTemplate = clone("effects/ColorCorrection")
    if awakeningTemplate then scope:add(awakeningTemplate) end
    local hitboxes = false
    local hitboxValue = find(roots.HitboxToggle, "Toggle")
    local hitboxButton = roots.HitboxToggle and roots.HitboxToggle:FindFirstChildWhichIsA("GuiButton", true)
    function module:setHitboxes(enabled)
        hitboxes = enabled == true
        if hitboxValue and hitboxValue:IsA("BoolValue") then hitboxValue.Value = hitboxes end
        text(find(hitboxButton, "TextLabel"), hitboxes and "Hitboxes: On" or "Hitboxes: Off")
    end
    function module:hitboxesEnabled() return hitboxes end
    bind(hitboxButton, function() module:setHitboxes(not hitboxes) end)
    module:setHitboxes(false)

    local getUpFrame = roots.getUp and roots.getUp:FindFirstChild("Frame")
    local getUpBar = find(getUpFrame, "bar")
    local mobileDash = find(roots.mobileButtons, "Dash")
    local mobileGetUp = find(roots.mobileButtons, "GetUp")
    local unusedMobileButton = find(roots.mobileButtons, "R")
    if unusedMobileButton then unusedMobileButton.Visible = false end
    bind(mobileDash, function() emit("Dash") end)
    bind(mobileGetUp, function() emit("GetUp") end)
    if roots.mobileButtons then roots.mobileButtons.Enabled = inputService.TouchEnabled end
    if getUpFrame then getUpFrame.Position = UDim2.new(0.5, 0, 1, 50) end
    if getUpBar then getUpBar.Size = UDim2.new(0, 0, 1, 0) end

    local emoteDisplay = find(roots.Emotes, "display")
    local emoteOpen = false
    bind(find(find(roots.Emotes, "button"), "ImageButton"), function()
        emoteOpen = not emoteOpen
        tween(emoteDisplay, 0.5, {Position = emoteOpen and UDim2.new(0.5, 0, 0.6, 0) or UDim2.new(0.5, 0, 1.3, 0)})
        ctx.audio:play({key = emoteOpen and "audio/onSFX" or "audio/offSFX"})
    end)
    if emoteDisplay then
        emoteDisplay.Position = UDim2.new(0.5, 0, 1.3, 0)
        for index, name in ipairs(emoteNames) do
            local button = find(emoteDisplay, tostring(index))
            local tag = tostring(index)
            if button and button:IsA("TextButton") then
                -- The stored ViewportFrames contain no preview rigs. Keep original
                -- button names/hotkey labels and identify the five safe dances.
                button.Text = name
                button.TextScaled = true
                button.TextWrapped = true
                bind(button, function() emit("Emote", tag) end)
            end
        end
    end
    local weaponButtons = {Bat = "Bat", Sword = "Sword", Sword2 = ":3", Sword3 = "BoyKisser", cat = "Maxwell", cat2 = "Orange Cat"}
    local selectedWeapon
    for buttonName, weaponName in pairs(weaponButtons) do
        local selectedName = weaponName
        bind(find(roots.weapon, buttonName), function()
            selectedWeapon = selectedName
            emit("Equip", selectedName)
        end)
    end
    bind(roots.weaponGui and roots.weaponGui:FindFirstChildWhichIsA("GuiButton", true), function()
        if roots.weapon then roots.weapon.Enabled = not roots.weapon.Enabled end
    end)

    local subtitleLabel = find(roots.Subtitles, "TextLabel")
    local subtitle
    function module:showSubtitle(data)
        if not subtitleLabel or type(data) ~= "table" then return end
        if data.character and data.character ~= player.Character then return end
        if type(data.text) ~= "string" then return end
        subtitle = {started = tick(), duration = math.max(0, math.min(30, tonumber(data.duration) or 1.2))}
        subtitleLabel.Text = data.text
        subtitleLabel.TextTransparency = 1
        subtitleLabel.TextStrokeTransparency = 1
    end

    local awakenImages = {}
    if roots.awakenScreen then
        for _, item in ipairs(roots.awakenScreen:GetDescendants()) do
            if item:IsA("ImageLabel") then item.Visible = false; awakenImages[#awakenImages + 1] = item end
        end
    end
    local awakening
    local function clearAwakening()
        if awakening and awakening.scope then awakening.scope:destroy() end
        awakening = nil
        for _, item in ipairs(awakenImages) do item.Visible = false end
    end
    function module:showAwaken(data)
        if type(data) ~= "table" or data.character ~= player.Character then return end
        clearAwakening()
        local childScope = scope:scope()
        local light = awakeningTemplate and awakeningTemplate:Clone()
        if light then childScope:add(light); light.Parent = lighting end
        awakening = {started = tick(), scope = childScope, light = light}
        for _, item in ipairs(awakenImages) do item.Visible = true; item.ImageTransparency = 0 end
    end

    local hitFrame = find(roots.HitIndicator, "Frame")
    local hitCount, hitDamage, hitTime = 0, 0, 0
    if hitFrame then hitFrame.Visible = false end
    local function confirmedDamage(data)
        if type(data) ~= "table" or (data.attacker ~= player.Character and data.attackerUserId ~= player.UserId) then return end
        if type(data.amount) ~= "number" or data.amount <= 0 then return end
        if tick() - hitTime >= 3 then hitCount = 0; hitDamage = 0 end
        hitCount = hitCount + 1
        hitDamage = hitDamage + data.amount
        hitTime = tick()
        if hitFrame then
            hitFrame.Visible = true
            text(find(hitFrame, "Hits"), hitCount)
            text(find(hitFrame, "Damage"), string.format("%.1f", hitDamage))
            tween(hitFrame, 0.2, {Size = UDim2.new(0.144, 0, 0.272, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end

    local voteScope
    local voteRows = {}
    local voteSignature = ""
    local voteDeadline = 0
    local voteActive = false
    local voteLastSecond
    local voteFrame = find(roots.MapVoteGui, "MapVoteFrame")
    if roots.MapVoteGui then roots.MapVoteGui.Enabled = true end
    if voteFrame then voteFrame.Visible = false end
    local voteRevision = -1
    function module:updateVoting(data)
        if type(data) ~= "table" or not voteFrame then return end
        local revision = data.revision or 0
        if revision < voteRevision then return end
        voteRevision = revision
        voteActive = data.active == true
        voteFrame.Visible = voteActive
        voteDeadline = tick() + math.max(0, tonumber(data.remaining) or 0)
        voteLastSecond = nil
        local candidates = {}
        for _, candidate in ipairs(data.candidates or {}) do
            if type(candidate) == "string" then candidates[#candidates + 1] = candidate end
        end
        table.sort(candidates)
        local signature = table.concat(candidates, "\0")
        if signature ~= voteSignature then
            voteSignature = signature
            if voteScope then voteScope:destroy() end
            voteScope = scope:scope()
            voteRows = {}
            local container = find(voteFrame, "MapsContainer")
            if container and voteTemplate then
                for index, name in ipairs(candidates) do
                    local mapName = name
                    local row = voteTemplate:Clone()
                    row.Name = name
                    row.LayoutOrder = index
                    row.Visible = true
                    text(find(row, "MapName"), name)
                    bind(find(row, "VoteButton"), function() emit("Vote", mapName) end, voteScope)
                    row.Parent = container
                    voteScope:add(row)
                    voteRows[name] = row
                end
            elseif not voteTemplate and not warned.MapFrame then
                warned.MapFrame = true
                ctx.report("Original MapFrame asset is unavailable; map vote controls cannot render.")
            end
        end
        for name, row in pairs(voteRows) do text(find(row, "NumVotes"), "Votes: " .. tostring((data.votes or {})[name] or 0)) end
    end

    local function removeBillboard(character)
        local entry = billboards[character]
        if entry then
            billboards[character] = nil
            entry.scope:destroy()
        end
    end
    local function updateSociety()
        local highest, winner = 0, nil
        for _, state in pairs(ctx.state:all()) do
            local kills = tonumber(state.kills) or 0
            if state.character and state.character.Parent and state.userId and state.userId > 0
                and (kills > highest or (kills == highest and kills > 0 and winner and state.userId < winner.userId)) then
                highest, winner = kills, state
            end
        end
        for character, entry in pairs(billboards) do
            if entry.society then entry.society.Enabled = winner ~= nil and winner.character == character end
        end
    end
    local function updateBillboard(state)
        local character = state.character
        if not character or not character.Parent then return end
        local entry = billboards[character]
        if not entry then
            local childScope = scope:scope()
            entry = {scope = childScope, state = state}
            billboards[character] = entry
            childScope:add(function()
                if billboards[character] == entry then billboards[character] = nil end
            end)
            childScope:add(character.ChildAdded:Connect(function(child)
                if child.Name == "Head" then module:update(entry.state) end
            end))
            childScope:add(character.AncestryChanged:Connect(function(_, parent)
                if not parent then removeBillboard(character) end
            end))
        end
        entry.state = state
        local head = character:FindFirstChild("Head")
        if not head then return end
        for _, name in ipairs({"stats", "society"}) do
            if not entry[name] and roots[name] then
                entry[name] = roots[name]:Clone()
                entry[name].Adornee = head
                entry[name].Parent = playerGui
                entry.scope:add(entry[name])
            elseif entry[name] then
                entry[name].Adornee = head
            end
        end
        local stats = entry.stats
        if stats then
            local characterPlayer = players:GetPlayerFromCharacter(character)
            local label = find(stats, "TextLabel")
            text(label, characterPlayer and characterPlayer.DisplayName or character.Name)
            if label then label.TextColor3 = state.downed and Color3.fromRGB(255, 42, 66) or Color3.fromRGB(255, 255, 255) end
            local health = find(stats, "health")
            local healthBar = health and health:FindFirstChild("Frame")
            local fraction = math.max(0, math.min(1, (tonumber(state.health) or 0) / math.max(1, tonumber(state.maxHealth) or 100)))
            if healthBar then tween(healthBar, 0.15, {Size = UDim2.new(fraction, 0, 1, 0)}) end
        end
    end

    local shiftlock = false
    local shiftCharacter
    local shiftHumanoid
    local originalAutoRotate, originalCameraOffset
    local shiftButton = find(roots.Shiftlock, "ImageButton")
    if roots.Shiftlock then roots.Shiftlock.Enabled = inputService.TouchEnabled end
    local function restoreShiftlock()
        if shiftHumanoid then
            pcall(function()
                shiftHumanoid.CameraOffset = originalCameraOffset
                shiftHumanoid.AutoRotate = originalAutoRotate
            end)
        end
        shiftCharacter, shiftHumanoid = nil, nil
    end
    local function setShiftlock(enabled)
        shiftlock = enabled == true
        if shiftButton then
            shiftButton.Image = shiftlock and "rbxasset://textures/ui/mouseLock_on@2x.png" or "rbxasset://textures/ui/mouseLock_off@2x.png"
        end
        if not shiftlock then restoreShiftlock() end
    end
    bind(shiftButton, function() setShiftlock(not shiftlock) end)
    setShiftlock(false)
    local getUpShown = false
    function module:update(state)
        if not alive or type(state) ~= "table" then return end
        updateBillboard(state)
        updateSociety()
        if state.character ~= player.Character then return end
        local eligible = state.downed == true and state.canGetUp == true and not state.carriedBy
        if eligible ~= getUpShown then
            getUpShown = eligible
            tween(getUpFrame, 0.5, {Position = eligible and UDim2.new(0.5, 0, 1, -50) or UDim2.new(0.5, 0, 1, 50)})
        end
        if getUpBar then
            local progress = math.max(0, math.min(1, tonumber(state.getUpProgress) or 0))
            tween(getUpBar, 0.15, {Size = UDim2.new(progress, 0, 1, 0)})
        end
        if mobileGetUp then mobileGetUp.Visible = eligible end
        if mobileDash then
            mobileDash.Visible = not state.downed and not state.ragdolled and not state.carrying
                and not state.carriedBy and state.weapon ~= nil and state.weapon ~= ""
        end
        if selectedWeapon and state.weapon == selectedWeapon and roots.weapon then
            roots.weapon.Enabled = false
            selectedWeapon = nil
        end
        if state.downed or state.ragdolled or state.busy or state.canAct == false then setShiftlock(false) end
    end

    -- Preserve the original title, emote toggle and hitbox-toggle bobbing without
    -- untracked infinite tweens or delay threads that outlive reexecution.
    local floaters = {}
    local function floater(object, seconds, yTarget, rotation)
        if object then floaters[#floaters + 1] = {object = object, position = object.Position,
            rotation = object.Rotation, period = seconds * 2, yTarget = yTarget, angle = rotation} end
    end
    floater(find(roots.title, "TextLabel"), 1, 50, -5)
    floater(find(roots.title, "dis"), 1, 75, -5)
    floater(find(roots.title, "disc"), 1, 100, -5)
    floater(find(roots.Emotes, "button"), 1.3, 10, -2)
    floater(hitboxButton, 1.7, nil, 4)
    local started = tick()
    scope:add(runService.RenderStepped:Connect(function()
        local now = tick()
        for _, entry in ipairs(floaters) do
            local alpha = (1 - math.cos((now - started) * 2 * math.pi / entry.period)) / 2
            local position = entry.position
            if entry.yTarget then entry.object.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale,
                position.Y.Offset + (entry.yTarget - position.Y.Offset) * alpha) end
            entry.object.Rotation = entry.rotation + (entry.angle - entry.rotation) * alpha
        end
        if shiftlock then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local camera = workspace.CurrentCamera
            if humanoid and root and humanoid.Health > 0 and camera and camera.CameraType ~= Enum.CameraType.Scriptable then
                if shiftCharacter ~= character then
                    restoreShiftlock()
                    shiftCharacter, shiftHumanoid = character, humanoid
                    originalAutoRotate, originalCameraOffset = humanoid.AutoRotate, humanoid.CameraOffset
                end
                humanoid.AutoRotate = false
                humanoid.CameraOffset = originalCameraOffset + Vector3.new(1.7, 0, 0)
                local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
                if look.Magnitude > 0.01 then root.CFrame = CFrame.new(root.Position, root.Position + look) end
            end
        end
        if subtitle and subtitleLabel then
            local elapsed = now - subtitle.started
            local alpha = elapsed < 0.3 and (1 - elapsed / 0.3) or math.max(0, elapsed - 0.3 - subtitle.duration)
            alpha = math.min(1, alpha)
            subtitleLabel.TextTransparency, subtitleLabel.TextStrokeTransparency = alpha, alpha
            if elapsed >= subtitle.duration + 1.3 then subtitle = nil end
        end
        if awakening then
            local elapsed = now - awakening.started
            local alpha = math.max(0, math.min(1, elapsed / 0.5))
            for _, item in ipairs(awakenImages) do item.ImageTransparency = alpha end
            local light = awakening.light
            if light then
                local strength = elapsed < 0.1 and elapsed / 0.1 or (1 - alpha)
                light.Brightness, light.Contrast, light.Saturation = 0.5 * strength, strength, strength
                light.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 20, 29), strength)
            end
            if elapsed >= 0.5 then clearAwakening() end
        end
        if hitFrame and hitFrame.Visible and now - hitTime >= 3 then
            hitFrame.Visible = false
            hitCount, hitDamage = 0, 0
        end
        if voteActive then
            local remaining = math.max(0, math.ceil(voteDeadline - now))
            if remaining ~= voteLastSecond then
                voteLastSecond = remaining
                text(find(voteFrame, "Title"), "Vote for a map (" .. tostring(remaining) .. ")")
            end
        end
    end))
    scope:add(inputService.LastInputTypeChanged:Connect(function(inputType)
        if inputType == Enum.UserInputType.Touch then
            if roots.mobileButtons then roots.mobileButtons.Enabled = true end
            if roots.Shiftlock then roots.Shiftlock.Enabled = true end
        end
    end))
    scope:add(ctx.state:onChanged(function(state) if state then module:update(state) end end))
    scope:add(ctx.network:on("Subtitle", function(data) module:showSubtitle(data) end))
    scope:add(ctx.network:on("Awaken", function(data) module:showAwaken(data) end))
    scope:add(ctx.network:on("Voting", function(data) module:updateVoting(data) end))
    scope:add(ctx.network:on("Damage", confirmedDamage))
    scope:add(ctx.network:on("Remove", function(data)
        if data and data.character then removeBillboard(data.character); updateSociety() end
    end))
    scope:add(player.CharacterAdded:Connect(function(character)
        if localCharacter then removeBillboard(localCharacter) end
        localCharacter = character
        setShiftlock(false)
        clearAwakening()
        selectedWeapon, subtitle = nil, nil
        if subtitleLabel then subtitleLabel.Text = "" end
        hitCount, hitDamage, hitTime = 0, 0, 0
        if hitFrame then hitFrame.Visible = false end
        getUpShown = false
        if getUpFrame then cancelTween(getUpFrame); getUpFrame.Position = UDim2.new(0.5, 0, 1, 50) end
        if getUpBar then cancelTween(getUpBar); getUpBar.Size = UDim2.new(0, 0, 1, 0) end
    end))
    scope:add(function()
        alive = false
        restoreShiftlock()
        clearAwakening()
        local objects = {}
        for object in pairs(tweens) do objects[#objects + 1] = object end
        for _, object in ipairs(objects) do cancelTween(object) end
        listeners = {}
        billboards = {}
    end)
    function module:destroy() scope:destroy() end
    for _, state in pairs(ctx.state:all()) do module:update(state) end
    return module
end
