-- Restore readable scoreboard labels locally, including players joining later.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local reverse,original={},setmetatable({},{__mode='k'})
    for label,id in pairs(ctx.identifiers.stats or {}) do reverse[id]=label end
    local watched=setmetatable({},{__mode='k'})
    local function stat(value)
        if watched[value] then return end;watched[value]=true
        local function label()
            if scope.dead then return end
            local text=reverse[value.Name]
            if text then original[value]=value.Name;value.Name=text end
        end
        scope:add(value:GetPropertyChangedSignal('Name'):Connect(label));label()
    end
    local function folder(value)
        if value.Name~='leaderstats' then return end
        for _,child in ipairs(value:GetChildren()) do stat(child) end
        scope:add(value.ChildAdded:Connect(stat))
    end
    local function player(value)
        for _,child in ipairs(value:GetChildren()) do folder(child) end
        scope:add(value.ChildAdded:Connect(folder))
    end
    local players=game:GetService('Players')
    for _,value in ipairs(players:GetPlayers()) do player(value) end
    scope:add(players.PlayerAdded:Connect(player))
    scope:add(function() for value,name in pairs(original) do if value.Parent then pcall(function() value.Name=name end) end end end)
    return {destroy=function() scope:destroy() end}
end
