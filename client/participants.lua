-- Local visibility only; characters, collisions and morphs remain server owned.
return function(ctx)
    local Players=game:GetService("Players")
    local scope=ctx.cleanup:scope()
    local active=false
    local observers={}
    local attribute=assert(ctx.protocol.clientWorld.readyAttribute)
    local function hide(character,parent)
        local hidden=parent:scope()
        local function property(object,key,value)
            local ok,saved=pcall(function() return object[key] end)
            if not ok then return end
            local changing=false
            local function apply()
                if hidden.dead or changing then return end
                local current=object[key]
                if current~=value then saved=current end
                changing=true;object[key]=value;changing=false
            end
            hidden:add(object:GetPropertyChangedSignal(key):Connect(apply))
            hidden:add(function() pcall(function() if object[key]==value then object[key]=saved end end) end)
            apply()
        end
        local function visit(object)
            if object:IsA("BasePart") then property(object,"LocalTransparencyModifier",1)
            elseif object:IsA("Decal") or object:IsA("Texture") then property(object,"Transparency",1)
            elseif object:IsA("Humanoid") then
                property(object,"DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None)
            elseif object:IsA("BillboardGui") or object:IsA("SurfaceGui") or object:IsA("ParticleEmitter")
                or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Highlight") then property(object,"Enabled",false)
            elseif object:IsA("Sound") then property(object,"Volume",0) end
        end
        hidden:add(character.DescendantAdded:Connect(visit))
        for _,object in ipairs(character:GetDescendants()) do visit(object) end
        return hidden
    end
    local function observe(player)
        if player==Players.LocalPlayer then return end
        local owned=scope:scope()
        local hidden,character
        local function refresh()
            local current=player.Character
            if hidden and (not active or character~=current or player:GetAttribute(attribute)==true) then hidden:destroy();hidden=nil end
            character=current
            if active and current and not hidden and player:GetAttribute(attribute)~=true then hidden=hide(current,owned) end
        end
        observers[player]=refresh
        owned:add(player:GetAttributeChangedSignal(attribute):Connect(refresh))
        owned:add(player.CharacterAdded:Connect(refresh))
        owned:add(Players.PlayerRemoving:Connect(function(leaving) if leaving==player then observers[player]=nil;owned:destroy() end end))
        refresh()
    end
    scope:add(Players.PlayerAdded:Connect(observe))
    for _,player in ipairs(Players:GetPlayers()) do observe(player) end
    return {setActive=function(_,value)
        if scope.dead then return end
        active=value==true
        for _,refresh in pairs(observers) do refresh() end
    end,destroy=function() scope:destroy();observers={} end}
end
