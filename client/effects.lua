-- Source combat presentation only. This module never reports hits or changes health.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local runService = game:GetService("RunService")
    local player = game:GetService("Players").LocalPlayer
    local active, auras, trails, warned = {}, {}, {}, {}
    local alive = true
    local module = {}
    local folder = Instance.new("Folder")
    folder.Name = "FunCombatEffects"
    folder.Parent = workspace
    scope:add(folder)

    local function finite(value, default)
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return default end
        return value
    end
    local function duration(value, default)
        return math.max(0.01, math.min(30, finite(value, default)))
    end
    local function report(key, message)
        if not warned[key] then warned[key] = true; ctx.report(message) end
    end
    local function characterPart(character, name)
        if typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent then return nil end
        local part = character:FindFirstChild(name or "HumanoidRootPart")
        if part and part:IsA("BasePart") then return part end
        return nil
    end
    local function effect(character, seconds)
        local childScope = scope:scope()
        local entry = {scope = childScope, character = character, started = tick(), emissions = {}, emitters = {}, closed = false}
        if seconds then entry.deadline = entry.started + seconds end
        active[entry] = true
        childScope:add(function() entry.closed = true; active[entry] = nil end)
        return entry
    end
    local function clone(entry, key)
        if entry.closed or not alive then return nil end
        if not ctx.catalog.packages[key] then
            report(key, "Original effect asset is unavailable: " .. key)
            return nil
        end
        local ok, object = pcall(function() return ctx.assets:clone(key) end)
        if not ok or typeof(object) ~= "Instance" then
            report(key, "Original effect could not load: " .. key .. ". " .. tostring(object))
            return nil
        end
        entry.scope:add(object)
        if entry.closed or not alive or (entry.character and not entry.character.Parent) then return nil end
        return object
    end
    local function each(root, callback)
        callback(root)
        for _, object in ipairs(root:GetDescendants()) do callback(object) end
    end
    local function tail(entry, seconds)
        if entry.deadline then entry.deadline = math.max(entry.deadline, entry.started + seconds) end
    end
    local function emit(entry, root, count, delay, continuous)
        delay = math.max(0, math.min(10, finite(delay, 0)))
        each(root, function(object)
            if object:IsA("ParticleEmitter") then
                local lifetime = math.max(0, finite(object.Lifetime.Max, 1))
                object.Enabled = continuous == true
                entry.emitters[#entry.emitters + 1] = object
                tail(entry, delay + lifetime + 0.1)
                if not continuous then
                    local amount = math.floor(math.max(0, math.min(500, finite(count, finite(object:GetAttribute("EmitCount"), 1)))))
                    local emitDelay = delay + math.max(0, math.min(10, finite(object:GetAttribute("EmitDelay"), 0)))
                    entry.emissions[#entry.emissions + 1] = {object = object, count = amount, at = entry.started + emitDelay}
                    tail(entry, emitDelay + lifetime + 0.1)
                end
            elseif object:IsA("Trail") then
                object.Enabled = continuous == true
                entry.emitters[#entry.emitters + 1] = object
                tail(entry, delay + math.max(0, finite(object.Lifetime, 0.5)) + 0.1)
            end
        end)
    end
    local function nonPhysical(part)
        part.Anchored, part.CanCollide, part.Massless = true, false, true
        pcall(function() part.CanTouch = false end)
        pcall(function() part.CanQuery = false end)
    end
    local function attach(entry, object, target, frame)
        if object:IsA("BasePart") then
            nonPhysical(object)
            object.CFrame = frame or target.CFrame
            object.Parent = folder
        elseif object:IsA("Attachment") or object:IsA("ParticleEmitter") or object:IsA("Trail") then
            object.Parent = target
        elseif object:IsA("Highlight") then
            object.Adornee, object.Parent = entry.character, entry.character
        else
            -- Exported container roots do not emit particles; move their owned
            -- children to the physical target without touching source instances.
            for _, child in ipairs(object:GetChildren()) do
                entry.scope:add(child)
                attach(entry, child, target, frame)
            end
        end
    end

    local function flash(entry, fill, outline, seconds)
        local ok, highlight = pcall(Instance.new, "Highlight")
        if not ok then
            report("Highlight", "Highlight is unsupported by this engine; source outline flashes are unavailable.")
            return
        end
        entry.scope:add(highlight)
        highlight.Name = "Highlight"
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.FillColor, highlight.OutlineColor = fill, outline
        highlight.FillTransparency, highlight.OutlineTransparency = 0.5, 0
        highlight.Adornee, highlight.Parent = entry.character, entry.character
        local started = tick()
        entry.flash = {object = highlight, start = started, duration = seconds}
        tail(entry, seconds)
    end

    local function dash(character, seconds, limbsOnly, smokeOnly)
        local root = characterPart(character)
        if not root then return end
        local entry = effect(character, seconds + 2)
        entry.disableAt = entry.started + seconds
        if not smokeOnly then
            for _, name in ipairs({"Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
                local limb = characterPart(character, name)
                if limb then
                    local source = clone(entry, "effects/dash_limbs")
                    if source then
                        -- Clone the whole source Part before moving children so
                        -- Trail attachment references remain internal and valid.
                        emit(entry, source, nil, seconds, true)
                        for _, child in ipairs(source:GetChildren()) do
                            entry.scope:add(child)
                            child.Parent = limb
                        end
                    end
                end
            end
            local state = ctx.state:get(character)
            local color = state and state.awakened and Color3.fromRGB(255, 0, 0) or Color3.new(1, 1, 1)
            flash(entry, color, color, 0.4)
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not limbsOnly and (not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air) then
            local source = clone(entry, "effects/dash_smoke")
            if source then
                emit(entry, source, nil, seconds, true)
                for _, child in ipairs(source:GetChildren()) do
                    entry.scope:add(child)
                    child.Parent = root
                end
            end
        end
    end

    local function aura(character)
        if auras[character] or typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent then return end
        local entry = effect(character)
        auras[character] = entry
        entry.scope:add(function() if auras[character] == entry then auras[character] = nil end end)
        local source = clone(entry, "effects/Killstreak")
        if not source then entry.scope:destroy(); return end
        local installed = {}
        local function install(part)
            if entry.closed or not part:IsA("BasePart") or part.Name == "HumanoidRootPart" or part.Name == "Torso" or installed[part] then return end
            installed[part] = true
            for _, original in ipairs(source:GetChildren()) do
                if original:IsA("ParticleEmitter") then
                    local object = original:Clone()
                    entry.scope:add(object)
                    object.Enabled, object.Parent = true, part
                end
            end
        end
        for _, part in ipairs(character:GetChildren()) do install(part) end
        entry.scope:add(character.ChildAdded:Connect(install))
        -- The source creates multiple identical highlights in its limb loop.
        -- One copy reproduces the visible flash without stacked highlights.
        local original = source:FindFirstChildWhichIsA("Highlight")
        if original then
            local object = original:Clone()
            entry.scope:add(object)
            object.Adornee, object.Parent = character, character
            object.FillTransparency, object.OutlineTransparency = 0.5, 0
            entry.flash = {object = object, start = tick(), duration = 1}
        end
    end

    function module:stop(character)
        local remove = {}
        for entry in pairs(active) do
            if entry.character == character then remove[#remove + 1] = entry end
        end
        for _, entry in ipairs(remove) do entry.scope:destroy() end
        trails[character] = nil
        if ctx.weapons then ctx.weapons:setTrails(character, false) end
    end

    function module:showHitbox(data)
        if not alive or type(data) ~= "table" or not ctx.gui or not ctx.gui:hitboxesEnabled() then return end
        local frame = data.cframe or data.frame
        if typeof(frame) ~= "CFrame" or typeof(data.size) ~= "Vector3" then return end
        if data.size.X <= 0 or data.size.Y <= 0 or data.size.Z <= 0 then return end
        local entry = effect(data.character, duration(data.duration, 0.05))
        local part = Instance.new("Part")
        entry.scope:add(part)
        part.Name = "hitbox_ref"
        nonPhysical(part)
        part.Transparency, part.Material = 0.95, Enum.Material.SmoothPlastic
        part.Size, part.CFrame = data.size, frame
        part.Color = data.phase == "startup" and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
        local outline = Instance.new("SelectionBox")
        outline.Adornee, outline.LineThickness, outline.Color3 = part, 0.03, part.Color
        outline.Parent = part
        part.Parent = folder
    end

    local function damageIndicator(character, key, amount)
        local target = characterPart(character)
        if not target then return end
        local entry = effect(character, 1.05)
        local object = clone(entry, key)
        if not object or not object:IsA("BillboardGui") then entry.scope:destroy(); return end
        local label = object:FindFirstChild("Damage")
        if not label or not label:IsA("TextLabel") then entry.scope:destroy(); return end
        object.Adornee, object.Enabled = target, true
        object.StudsOffset = Vector3.new(math.random() * 3 - 1.5, math.random() * 2 - 1, math.random() - 0.5)
        label.Size, label.TextColor3 = UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1)
        if amount then label.Text = tostring(amount) end
        object.Parent = folder
        entry.indicator = label
    end

    -- Explosion is the source CameraShakePresets value (Stephen Leitnick, 2018).
    local shakes = {}
    function module:shake(character)
        if character ~= player.Character then return end
        shakes[#shakes + 1] = {started = tick(), noise = math.random(-100, 100)}
    end

    function module:play(data)
        if not alive or type(data) ~= "table" or type(data.key) ~= "string" then return end
        local character, key = data.character, data.key
        if key == "combat/Hitbox" then self:showHitbox(data); return end
        local root = characterPart(character)
        if not root then return end
        if key == "weapon/Trail" then
            local deadline = tick() + duration(data.duration, 0.5)
            local current = trails[character]
            if current then current.deadline = math.max(current.deadline, deadline)
            else trails[character] = {deadline = deadline} end
            if ctx.weapons then ctx.weapons:setTrails(character, true) end
            return
        elseif key == "effects/Dash" or key == "effects/dash_limbs" or key == "effects/dash_smoke" then
            dash(character, duration(data.duration, 0.3), key == "effects/dash_limbs", key == "effects/dash_smoke")
            return
        elseif key == "effects/Killstreak" then
            aura(character)
            self:shake(character)
            return
        end
        if key ~= "effects/Counter" and key ~= "effects/circles" and key ~= "effects/LevelUp/UpKill"
            and key ~= "effects/Hits/Default" and key ~= "effects/Hits/Heavy"
            and key ~= "effects/Hits/BackBreak" and key ~= "effects/Hits/WallBounce" then return end
        local entry = effect(character, duration(data.duration, 2))
        local target = characterPart(character, "Torso") or root
        local keys = {key}
        if key == "effects/LevelUp/UpKill" then
            target, keys = root, {}
            for candidate in pairs(ctx.catalog.packages) do
                if string.sub(candidate, 1, #key) == key then keys[#keys + 1] = candidate end
            end
            table.sort(keys)
            if #keys == 0 then report(key, "Original UpKill emitters are unavailable.") end
        end
        local loaded = false
        for _, assetKey in ipairs(keys) do
            local object = clone(entry, assetKey)
            if object then
                loaded = true
                attach(entry, object, target, typeof(data.frame) == "CFrame" and data.frame or nil)
                emit(entry, object, key == "effects/circles" and 35 or nil, key == "effects/circles" and 0.4 or 0)
            end
        end
        if string.sub(key, 1, 13) == "effects/Hits/" then
            local fill, outline = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
            if key == "effects/Hits/Heavy" then fill, outline = Color3.fromRGB(255, 88, 130), Color3.new(0, 0, 0)
            elseif key == "effects/Hits/BackBreak" then fill, outline = Color3.fromRGB(249, 255, 247), Color3.new(0, 0, 0) end
            flash(entry, fill, outline, 0.3)
        end
        if not loaded then entry.scope:destroy() end
    end

    scope:add(ctx.network:on("Effect", function(data) module:play(data) end))
    scope:add(ctx.network:on("Damage", function(data)
        if type(data) ~= "table" or not finite(data.amount, nil) or data.amount <= 0 then return end
        damageIndicator(data.character, data.amount >= 40 and "gui/DamageIndicatorCrit" or "gui/DamageIndicator", data.amount)
        if data.counter then damageIndicator(data.character, "gui/CounterIndicator") end
    end))
    scope:add(ctx.network:on("Remove", function(data) if data and data.character then module:stop(data.character) end end))
    scope:add(ctx.state:onChanged(function(state, previous)
        if not state then
            if previous and previous.character then module:stop(previous.character) end
            return
        end
        if not state.awakened or (state.health or 0) <= 0 then
            local entry = auras[state.character]
            if entry then entry.scope:destroy() end
        elseif not state.busy or (state.animation and state.animation.key ~= "other/awaken") then
            aura(state.character)
        end
    end))
    scope:add(runService.Heartbeat:Connect(function()
        local now, remove = tick(), {}
        for entry in pairs(active) do
            if entry.closed or (entry.character and not entry.character.Parent) or (entry.deadline and now >= entry.deadline) then
                remove[#remove + 1] = entry
            else
                for index = #entry.emissions, 1, -1 do
                    local emission = entry.emissions[index]
                    if now >= emission.at then
                        if emission.object.Parent then emission.object:Emit(emission.count) end
                        table.remove(entry.emissions, index)
                    end
                end
                if entry.disableAt and now >= entry.disableAt then
                    entry.disableAt = nil
                    for _, object in ipairs(entry.emitters) do if object.Parent then object.Enabled = false end end
                end
                if entry.flash then
                    local flashData = entry.flash
                    local alpha = math.max(0, math.min(1, (now - flashData.start) / flashData.duration))
                    if flashData.object.Parent then
                        flashData.object.FillTransparency, flashData.object.OutlineTransparency = 0.5 + 0.5 * alpha, alpha
                    end
                    if alpha >= 1 then entry.scope:remove(flashData.object); flashData.object:Destroy(); entry.flash = nil end
                end
                if entry.indicator then
                    local elapsed, scale = now - entry.started, 0
                    if elapsed < 0.1 then scale = 0.9 * elapsed / 0.1
                    elseif elapsed < 0.2 then
                        local alpha = (elapsed - 0.1) / 0.1
                        scale = 0.9 - 0.15 * (1 - (1 - alpha) * (1 - alpha))
                    elseif elapsed < 0.85 then scale = 0.75
                    else
                        local alpha = math.max(0, math.min(1, (elapsed - 0.85) / 0.2))
                        local eased = alpha * alpha * ((1.70158 + 1) * alpha - 1.70158)
                        scale = 0.75 * (1 - eased)
                    end
                    entry.indicator.Size = UDim2.new(scale, 0, scale, 0)
                end
            end
        end
        for _, entry in ipairs(remove) do entry.scope:destroy() end
        for character, entry in pairs(trails) do
            local weapon = ctx.weapons and ctx.weapons:get(character)
            if not character.Parent or now >= entry.deadline then
                if ctx.weapons then ctx.weapons:setTrails(character, false) end
                trails[character] = nil
            elseif weapon ~= entry.model then
                entry.model = weapon
                if ctx.weapons then ctx.weapons:setTrails(character, true) end
            end
        end
    end))

    local shakeName = "FunCombatCameraShake_" .. tostring({})
    local lastCamera, lastFrame, lastOffset
    local function clearCameraOffset()
        if lastCamera and lastCamera.Parent and lastFrame and lastCamera.CFrame == lastFrame then
            lastCamera.CFrame = lastFrame * lastOffset:Inverse()
        end
        lastCamera, lastFrame, lastOffset = nil, nil, nil
    end
    runService:BindToRenderStep(shakeName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        clearCameraOffset()
        local camera = workspace.CurrentCamera
        if not camera or #shakes == 0 then return end
        local position, rotation = Vector3.new(), Vector3.new()
        for index = #shakes, 1, -1 do
            local shake = shakes[index]
            local alpha = math.max(0, 1 - (tick() - shake.started) / 1.5)
            if alpha <= 0 then table.remove(shakes, index)
            else
                local t = shake.noise
                local offset = Vector3.new(math.noise(t, 0), math.noise(0, t), math.noise(t, t)) * 0.5 * 5 * alpha
                shake.noise = t + math.max(0, math.min(0.1, dt)) * 10 * alpha
                position = position + offset * Vector3.new(0.25, 0.25, 0.25)
                rotation = rotation + offset * Vector3.new(4, 1, 1)
            end
        end
        lastOffset = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation.Y), 0)
            * CFrame.Angles(math.rad(rotation.X), 0, math.rad(rotation.Z))
        lastCamera, lastFrame = camera, camera.CFrame * lastOffset
        camera.CFrame = lastFrame
    end)
    scope:add(function() runService:UnbindFromRenderStep(shakeName); clearCameraOffset() end)
    scope:add(player.CharacterAdded:Connect(function()
        shakes = {}
        clearCameraOffset()
    end))
    scope:add(function()
        alive = false
        for character in pairs(trails) do if ctx.weapons then ctx.weapons:setTrails(character, false) end end
        trails, shakes = {}, {}
    end)
    function module:destroy() scope:destroy() end
    for _, state in pairs(ctx.state:all()) do
        if state.awakened and (state.health or 0) > 0 then aura(state.character) end
    end
    return module
end
