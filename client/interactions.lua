-- Native hold UI remains attached to the original server prompt Instances.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local player=game:GetService("Players").LocalPlayer
    local prompts,names={},{}
    for logical,definition in pairs(ctx.identifiers.prompts) do names[definition.name]={logical=logical,definition=definition} end
    for name,definition in pairs(ctx.identifiers.mapPrompts or {}) do names[name]={logical="nativeWall",definition=definition} end
    local module={}
    local function characterOf(prompt)
        local parent=prompt.Parent
        while parent and parent~=workspace do
            if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return parent end
            parent=parent.Parent
        end
    end
    local function canShow(entry)
        local actor=ctx.state:localState()
        if not actor or actor.dead or actor.downed or actor.ragdolled or actor.stunned or actor.carriedBy then return false end
        if entry.logical=="nativeWall" then return actor.carrying~=nil and not actor.busy end
        local victim=characterOf(entry.prompt)
        local target=victim and ctx.state:get(victim)
        if not target or victim==player.Character or target.dead then return false end
        if entry.logical=="stopPrompt" then
            return actor.pairVictim==victim and target.pairActor==player.Character and not actor.pairReleasing
        end
        if actor.busy or target.busy then return false end
        if entry.logical=="dropPrompt" or entry.logical=="finishHoldPrompt" then
            return actor.carrying==victim and target.carriedBy==player.Character and target.downed
        end
        return not actor.carrying and not actor.attacking and actor.canAct~=false and target.downed and not target.carriedBy
    end
    local function apply(entry)
        local prompt=entry.prompt
        if entry.scope.dead or not prompt.Parent then return end
        local show=canShow(entry)==true
        if prompt.Enabled~=show then entry.writing=true;prompt.Enabled=show;entry.writing=false end
    end
    local function track(prompt)
        local definition=names[prompt.Name]
        if not prompt:IsA("ProximityPrompt") or not definition or prompts[prompt] then return end
        local s=scope:scope()
        local entry={prompt=prompt,logical=definition.logical,scope=s,original={ActionText=prompt.ActionText,ObjectText=prompt.ObjectText,Style=prompt.Style,Enabled=prompt.Enabled}}
        prompts[prompt]=entry
        prompt.ActionText=definition.definition.actionText;prompt.ObjectText=definition.definition.objectText
        prompt.Style=Enum.ProximityPromptStyle.Default
        s:add(prompt:GetPropertyChangedSignal("Enabled"):Connect(function() if not entry.writing then apply(entry) end end))
        s:add(prompt.AncestryChanged:Connect(function(_,parent) if not parent then s:destroy() end end))
        s:add(function()
            prompts[prompt]=nil;entry.writing=true
            pcall(function()
                prompt.ActionText=entry.original.ActionText;prompt.ObjectText=entry.original.ObjectText;prompt.Style=entry.original.Style
                -- Opaque server copies remain hidden while the external runtime is absent.
                prompt.Enabled=false
            end)
        end)
        apply(entry)
    end
    local function refresh() for _,entry in pairs(prompts) do apply(entry) end end
    scope:add(workspace.DescendantAdded:Connect(track))
    scope:add(ctx.state:onChanged(function(state)
        if state and state.character then for _,item in ipairs(state.character:GetDescendants()) do track(item) end end
        refresh()
    end))
    scope:add(ctx.network:on("Remove",refresh))
    scope:add(player.CharacterAdded:Connect(refresh))
    for _,item in ipairs(workspace:GetDescendants()) do track(item) end
    function module:refresh() refresh() end
    function module:destroy() scope:destroy() end
    return module
end
