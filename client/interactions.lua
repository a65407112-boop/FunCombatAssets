-- Preserve native ProximityPrompt hold UI and server Triggered validation.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local player = game:GetService("Players").LocalPlayer
    local prompts = {}
    local names = {}
    for logical, definition in pairs(assert(ctx.identifiers.prompts, "Missing prompt identifier manifest")) do
        names[definition.name] = {logical=logical, definition=definition}
    end
    local module = {}
    local function kind(prompt)
        local entry = names[prompt.Name]
        return entry and entry.logical
    end

    local function characterOf(prompt)
        local current = prompt.Parent
        while current and current ~= workspace do
            if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then return current end
            current = current.Parent
        end
        return nil
    end

    local function allowed(prompt, victim)
        local actor = ctx.state:localState()
        local target = victim and ctx.state:get(victim)
        if not actor or not target or not player.Character or victim == player.Character then return false end
        if actor.dead or actor.downed or actor.ragdolled or actor.carriedBy or (actor.health or 0) <= 0 then return false end
        if actor.busy or actor.stunned then return false end
        if kind(prompt) == "dropPrompt" or kind(prompt) == "finishHoldPrompt" then
            -- Carrying itself makes canAct false; these actions use ownership.
            return actor.carrying == victim and target.carriedBy == player.Character
        end
        if actor.canAct == false or actor.attacking then return false end
        return not actor.carrying and target.downed and not target.carriedBy and not target.busy
    end

    local function serverAllows(prompt, target)
        if not target or target.dead or (target.health or 0) <= 0 or target.busy then return false end
        if kind(prompt) == "dropPrompt" or kind(prompt) == "finishHoldPrompt" then return target.carriedBy ~= nil end
        return target.downed == true and not target.carriedBy
    end

    local function apply(entry)
        local prompt = entry.prompt
        if entry.scope.dead or not prompt.Parent then return end
        local victim = characterOf(prompt)
        local target = victim and ctx.state:get(victim)
        -- A local Enabled write can fire later, after the writing guard clears.
        -- Authoritative state supplies availability; property signals only reapply it.
        if target then entry.serverEnabled = serverAllows(prompt, target) end
        local show = entry.serverEnabled and allowed(prompt, victim)
        if prompt.Enabled ~= show then
            entry.writing = true
            prompt.Enabled = show
            entry.writing = false
        end
    end

    local function track(prompt)
        if not prompt:IsA("ProximityPrompt") or not names[prompt.Name] or prompts[prompt] then return end
        -- Only prompts on an actual character are filtered; map prompts are untouched.
        if not characterOf(prompt) then return end
        local childScope = scope:scope()
        local entry = {prompt = prompt, serverEnabled = prompt.Enabled, writing = false, scope = childScope,
            original={ActionText=prompt.ActionText,ObjectText=prompt.ObjectText,Style=prompt.Style}}
        prompts[prompt] = entry
        local display = names[prompt.Name].definition
        -- Server keeps opaque labels and Custom style. Native original hold UI
        -- is enabled only in this external client, without replacing the prompt.
        prompt.ActionText, prompt.ObjectText = display.actionText, display.objectText
        prompt.Style = Enum.ProximityPromptStyle.Default
        childScope:add(prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not entry.writing then apply(entry) end
        end))
        childScope:add(prompt.AncestryChanged:Connect(function(_, parent)
            if not parent then childScope:destroy() end
        end))
        childScope:add(function()
            prompts[prompt] = nil
            entry.writing = true
            pcall(function()
                prompt.Enabled = entry.serverEnabled
                prompt.ActionText, prompt.ObjectText, prompt.Style = entry.original.ActionText, entry.original.ObjectText, entry.original.Style
            end)
        end)
        apply(entry)
    end

    local function refresh()
        for _, entry in pairs(prompts) do apply(entry) end
    end
    scope:add(workspace.DescendantAdded:Connect(track))
    scope:add(ctx.state:onChanged(function(state)
        if state and state.character then
            for _, descendant in ipairs(state.character:GetDescendants()) do track(descendant) end
        end
        refresh()
    end))
    scope:add(player.CharacterAdded:Connect(refresh))
    for _, item in ipairs(workspace:GetDescendants()) do track(item) end
    function module:refresh() refresh() end
    function module:destroy() scope:destroy() end
    return module
end
