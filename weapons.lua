-- Original weapon cosmetics. Combat and ownership remain server-authoritative.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local entries = {}
    local pending = {}
    local alive = true
    local module = {}
    local allowed = {Bat = true, Sword = true, [":3"] = true, BoyKisser = true, Maxwell = true, ["Orange Cat"] = true}
    local reported = {}

    local function report(message)
        if not reported[message] then
            reported[message] = true
            ctx.report(message)
        end
    end

    local function remove(character)
        local request = pending[character]
        pending[character] = nil
        if request then request.scope:destroy() end
        local entry = entries[character]
        if entry then
            entries[character] = nil
            entry.scope:destroy()
        end
    end

    function module:get(character)
        local entry = entries[character]
        return entry and entry.model or nil
    end

    function module:getSound(character, name)
        local model = self:get(character)
        if model then
            for _, item in ipairs(model:GetDescendants()) do
                if item:IsA("Sound") and item.Name == name then
                    return item
                end
            end
        end
        return nil
    end

    function module:setTrails(character, enabled)
        local model = self:get(character)
        if model then
            for _, item in ipairs(model:GetDescendants()) do
                if item:IsA("Trail") then item.Enabled = enabled == true end
            end
        end
    end

    function module:update(state)
        if not alive or type(state) ~= "table" or not state.character then return end
        local character = state.character
        local name = state.weapon
        if not character.Parent or not allowed[name] then remove(character); return end
        local current = entries[character]
        if current and current.name == name and current.model.Parent == character then return end
        if pending[character] then
            pending[character].state = state
            return
        end
        local arm = character:FindFirstChild("Right Arm")
        if not arm or not arm:IsA("BasePart") then
            -- Character parts may arrive after the state event on a streamed spawn.
            local childScope = scope:scope()
            local request = {scope = childScope, state = state}
            pending[character] = request
            childScope:add(character.ChildAdded:Connect(function(child)
                if child.Name == "Right Arm" and child:IsA("BasePart") then
                    pending[character] = nil
                    childScope:destroy()
                    module:update(request.state)
                end
            end))
            childScope:add(character.AncestryChanged:Connect(function(_, parent)
                if not parent then remove(character) end
            end))
            childScope:add(function()
                if pending[character] == request then pending[character] = nil end
            end)
            return
        end
        remove(character)
        local childScope = scope:scope()
        local request = {scope = childScope, state = state}
        pending[character] = request
        childScope:add(function()
            if pending[character] == request then pending[character] = nil end
        end)
        local ok, source = pcall(function() return ctx.assets:clone("weapons/" .. name) end)
        if not ok or typeof(source) ~= "Instance" then
            local latest = pending[character] == request and request.state or nil
            if latest then pending[character] = nil end
            childScope:destroy()
            report("Weapon cosmetic could not load: " .. name .. ". " .. tostring(source))
            if latest and latest.weapon ~= name then self:update(latest) end
            return
        end
        childScope:add(source)
        if not alive or not character.Parent or pending[character] ~= request or request.state.weapon ~= name then
            local latest = pending[character] == request and request.state or nil
            if latest then pending[character] = nil end
            childScope:destroy()
            if latest and latest.weapon ~= name then self:update(latest) end
            return
        end
        local handle = source:FindFirstChild("Handle", true)
        if not handle or not handle:IsA("BasePart") then
            pending[character] = nil
            childScope:destroy()
            report("Original weapon has no usable Handle: " .. name)
            return
        end
        local grip = CFrame.new()
        if source:IsA("Tool") then grip = source.Grip end
        local model = Instance.new("Model")
        model.Name = source.Name
        childScope:add(model)
        local parts = {}
        local relative = {}
        for _, item in ipairs(source:GetDescendants()) do
            if item:IsA("BasePart") then
                parts[#parts + 1] = item
                relative[item] = handle.CFrame:ToObjectSpace(item.CFrame)
            end
        end
        -- Rebuild rigid cosmetic joints from their exported positions. No server Tool
        -- scripts, remotes, Humanoid, Animator or independent character rig is installed.
        for _, item in ipairs(source:GetDescendants()) do
            if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent") or item:IsA("RemoteFunction")
                or item:IsA("Humanoid") or item:IsA("AnimationController") or item:IsA("Animator")
                or item:IsA("JointInstance") or item:IsA("WeldConstraint") then
                item:Destroy()
            end
        end
        for _, item in ipairs(source:GetChildren()) do item.Parent = model end
        local attachment = arm:FindFirstChild("RightGripAttachment")
        -- R6's generated Tool grip uses this basis when the rig has no attachment.
        local armGrip = attachment and attachment:IsA("Attachment") and attachment.CFrame
            or CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
        local handleFrame = arm.CFrame * armGrip * grip:Inverse()
        for _, part in ipairs(parts) do
            part.Anchored = false
            part.CanCollide = false
            part.Massless = true
            pcall(function() part.CanTouch = false end)
            pcall(function() part.CanQuery = false end)
            part.CFrame = handleFrame * relative[part]
            if part ~= handle then
                local weld = Instance.new("Weld")
                weld.Name = "CosmeticWeld"
                weld.Part0 = handle
                weld.Part1 = part
                weld.C0 = relative[part]
                weld.C1 = CFrame.new()
                weld.Parent = handle
            end
        end
        for _, item in ipairs(model:GetDescendants()) do
            if item:IsA("Trail") then item.Enabled = false end
            if item:IsA("Sound") then item:Stop(); item.PlayOnRemove = false end
        end
        model.PrimaryPart = handle
        local motor = Instance.new("Motor6D")
        motor.Name = "RightGrip"
        motor.Part0 = arm
        motor.Part1 = handle
        motor.C0 = armGrip
        motor.C1 = grip
        childScope:add(motor)
        model.Parent = character
        motor.Parent = arm
        entries[character] = {name = name, model = model, scope = childScope, motor = motor}
        pending[character] = nil
        childScope:add(character.AncestryChanged:Connect(function(_, parent)
            if not parent then remove(character) end
        end))
        -- The animation player discovers the newly installed RightGrip by character.
        local latest = ctx.state:get(character)
        if latest and latest.weapon ~= name then self:update(latest) end
    end

    scope:add(ctx.state:onChanged(function(state) if state then module:update(state) end end))
    scope:add(ctx.network:on("Remove", function(data)
        if data and data.character then
            remove(data.character)
        end
    end))
    scope:add(function()
        alive = false
        for character in pairs(entries) do entries[character] = nil end
        for character in pairs(pending) do pending[character] = nil end
    end)
    function module:destroy() scope:destroy() end
    for _, state in pairs(ctx.state:all()) do module:update(state) end
    return module
end
