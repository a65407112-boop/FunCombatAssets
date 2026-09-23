return function(ctx)
    local scope = ctx.cleanup:scope()
    local lighting = game:GetService("Lighting")
    local saved = {}
    local holder = Instance.new("Folder")
    holder.Name = "FunCombatLightingRestore"
    local layer, name
    local revision, pending = -1, nil
    scope:add(function()
        pending = nil
        if layer then layer:destroy(); layer = nil end
        for object, parent in pairs(saved) do pcall(function() object.Parent = parent end) end
        saved = {}
        holder:Destroy()
    end)
    local settings = ctx.json("assets/manifests/rain-settings.json")
    assert(not scope.dead, "Weather initialization cancelled")
    local rain = ctx.rain
    rain:SetColor(Color3.fromRGB(unpack(settings.Color)))
    rain:SetDirection(Vector3.new(unpack(settings.Direction)))
    for _, method in ipairs({"Transparency","SpeedRatio","IntensityRatio","LightInfluence","LightEmission","Volume","SoundId","StraightTexture","TopDownTexture","SplashTexture"}) do
        if settings[method] ~= nil then rain["Set" .. method](rain, settings[method]) end
    end
    rain:SetCollisionMode(rain.CollisionMode.Function, function(part)
        return (not settings.TransparencyConstraint or part.Transparency <= settings.TransparencyThreshold)
            and (not settings.CanCollideConstraint or part.CanCollide)
    end)
    local module = {}
    function module:apply(data)
        if scope.dead or (data.revision or 0) < revision then return end
        revision = data.revision or 0
        local request = {}
        pending = request
        local nextName = data.name
        if nextName == name then return end
        local keys = {Sunny = "NormalLightning", Cloudy = "Rainy", Rainy = "Rainy", PurpleFog = "Purple/PurpleFog"}
        local key = keys[nextName]
        if not key then ctx.report("Unknown weather state: " .. tostring(nextName)); return end
        local newFolder = ctx.assets:clone("weather/" .. key)
        if scope.dead or pending ~= request then newFolder:Destroy(); return end
        if layer then layer:destroy() end
        layer = scope:scope()
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
                if not saved[child] then saved[child] = child.Parent; child.Parent = holder end
            end
        end
        for _, object in ipairs(newFolder:GetChildren()) do
            layer:add(object)
            object.Parent = object:IsA("Model") and workspace or lighting
        end
        newFolder:Destroy()
        if nextName == "Rainy" then rain:Enable() else rain:Disable() end
        name = nextName
    end
    scope:add(ctx.network:on("Weather", function(data) module:apply(data) end))
    function module:destroy() scope:destroy() end
    return module
end
