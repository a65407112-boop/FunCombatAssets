return function(ctx)
    local module = {cache = {}, warnings = {}}
    local scope = ctx.cleanup:scope()
    local function warnOnce(key, message)
        if not module.warnings[key] then module.warnings[key] = true; ctx.report(message) end
    end
    local function enumFromValue(enumType, value)
        for _, item in ipairs(enumType:GetEnumItems()) do if item.Value == value then return item end end
        error("Unsupported enum value " .. tostring(value))
    end
    local function decode(prop, object, name)
        local t, v = prop.type, prop.value
        if t == "string" or t == "bool" or t == "number" or t == "int" or t == "int64" then return v
        elseif t == "token" then
            local current = object[name]
            if typeof(current) == "EnumItem" then return enumFromValue(current.EnumType, v) end
            return v
        elseif t == "Color3" then return Color3.new(unpack(v))
        elseif t == "Vector2" then return Vector2.new(unpack(v))
        elseif t == "Vector3" then return Vector3.new(unpack(v))
        elseif t == "Vector3int16" then return Vector3int16.new(unpack(v))
        elseif t == "CFrame" then return CFrame.new(unpack(v))
        elseif t == "UDim" then return UDim.new(unpack(v))
        elseif t == "UDim2" then return UDim2.new(unpack(v))
        elseif t == "Rect" then return Rect.new(unpack(v))
        elseif t == "BrickColor" then return BrickColor.new(v)
        elseif t == "NumberRange" then return NumberRange.new(unpack(v))
        elseif t == "NumberSequence" then
            local keys = {}; for _, k in ipairs(v) do keys[#keys + 1] = NumberSequenceKeypoint.new(k[1], k[2], k[3]) end
            return NumberSequence.new(keys)
        elseif t == "ColorSequence" then
            local keys = {}; for _, k in ipairs(v) do keys[#keys + 1] = ColorSequenceKeypoint.new(k[1], Color3.new(k[2], k[3], k[4])) end
            return ColorSequence.new(keys)
        elseif t == "PhysicalProperties" then return v and PhysicalProperties.new(unpack(v)) or nil
        elseif t == "Font" then
            local weight = enumFromValue(Enum.FontWeight, v.weight)
            local style = Enum.FontStyle[v.style] or Enum.FontStyle.Normal
            return Font.new(v.family, weight, style)
        elseif t == "Faces" or t == "Axes" then
            local args = {}; local names = t == "Faces" and {"Right","Top","Back","Left","Bottom","Front"} or {"X","Y","Z"}
            for i, key in ipairs(names) do if math.floor(v / 2 ^ (i - 1)) % 2 == 1 then args[#args + 1] = (t == "Faces" and Enum.NormalId or Enum.Axis)[key] end end
            return (t == "Faces" and Faces or Axes).new(unpack(args))
        end
        error("Unsupported exported type " .. tostring(t))
    end
    local optional = {UIStroke = true, UIFlexItem = true, SurfaceAppearance = true, Highlight = true}
    local skip = {ReadOnly = true, Parent = true, Name = true, Archivable = false, Origin = true, CFrame = false}
    local critical = {CFrame = true, Size = true, Position = true, MeshId = true, TextureId = true, TextureID = true, AnimationId = true, SoundId = true, Image = true, Color = true, Text = true}

    function module:construct(data, key)
        local byId, made, meshes = {}, {}, {}
        local ok, err = pcall(function()
            for _, node in ipairs(data.nodes) do
                local cls = node.class
                if cls == "Script" or cls == "LocalScript" or cls == "ModuleScript" or cls == "RemoteEvent" or cls == "RemoteFunction" then error("Unexpected executable/network asset " .. key) end
                local object
                if cls == "MeshPart" then
                    -- MeshId is not normally writable on a new MeshPart. A
                    -- FileMesh using the same original vertices is an exact
                    -- visual geometry fallback, not a substitute weapon.
                    local meshId = node.properties.MeshId and node.properties.MeshId.value
                    object = Instance.new("MeshPart")
                    local assigned = pcall(function() object.MeshId = meshId end)
                    if not assigned or object.MeshId ~= meshId then
                        object:Destroy(); object = Instance.new("Part")
                        local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.FileMesh; mesh.MeshId = meshId or ""; mesh.Parent = object
                        meshes[node.id] = {mesh = mesh, node = node}
                        warnOnce("mesh-fallback", "Using original MeshId geometry through SpecialMesh on this client; PBR SurfaceAppearance cannot be reproduced by that backend.")
                    end
                elseif cls == "UnionOperation" then
                    error("This asset requires model deserialization: " .. key .. ". JSON cannot recreate embedded CSG; no replacement geometry was created.")
                else
                    local created, result = pcall(Instance.new, cls)
                    if created then object = result
                    elseif optional[cls] then warnOnce(cls, "Client does not support cosmetic class " .. cls .. "; see compatibility report.")
                    else error("Cannot construct " .. cls .. " in " .. key .. ": " .. tostring(result)) end
                end
                if object then object.Name = node.name; byId[node.id] = object; made[#made + 1] = object end
            end
            for _, node in ipairs(data.nodes) do
                local object = byId[node.id]
                if object then
                    for name, prop in pairs(node.properties) do
                        if prop.type ~= "Ref" and not skip[name] and not (meshes[node.id] and (name == "MeshId" or name == "TextureID" or name == "RenderFidelity" or name == "CollisionFidelity" or name == "DoubleSided")) then
                            local applied, why = pcall(function() object[name] = decode(prop, object, name) end)
                            if not applied then
                                if critical[name] then error(key .. ": " .. node.class .. "." .. name .. ": " .. tostring(why)) end
                                warnOnce(node.class .. "." .. name, "Skipped unsupported/read-only property " .. node.class .. "." .. name)
                            end
                        end
                    end
                    for name, value in pairs(node.attributes or {}) do pcall(function() object:SetAttribute(name, value) end) end
                    local fallback = meshes[node.id]
                    if fallback then
                        local size = node.properties.Size.value; local original = node.meshSize
                        if not original or original[1] <= 0 or original[2] <= 0 or original[3] <= 0 then error("Missing original mesh bounds for " .. key .. "/" .. node.name) end
                        fallback.mesh.Scale = Vector3.new(size[1]/original[1], size[2]/original[2], size[3]/original[3])
                        fallback.mesh.TextureId = node.properties.TextureID and node.properties.TextureID.value or ""
                    end
                end
            end
            for _, node in ipairs(data.nodes) do
                local object = byId[node.id]
                if object then
                    if node.parent then object.Parent = byId[node.parent] end
                    for name, prop in pairs(node.properties) do
                        if prop.type == "Ref" then
                            local success, why = pcall(function() object[name] = prop.value and byId[prop.value] or nil end)
                            if not success and prop.value then error(key .. " reference " .. name .. ": " .. tostring(why)) end
                        end
                    end
                end
            end
        end)
        if not ok then for _, object in ipairs(made) do pcall(function() object:Destroy() end) end; error(err) end
        return assert(byId[data.root], "Missing root in asset " .. key)
    end
    function module:clone(key)
        if not self.cache[key] then
            local entry = assert(ctx.catalog.packages[key], "Missing asset manifest entry: " .. tostring(key))
            local data = ctx.json(entry.path)
            assert(not ctx.cleanup.dead, "Asset load cancelled: " .. key)
            if data.version ~= 1 or #data.nodes ~= entry.count then error("Invalid asset package: " .. key) end
            local root = self:construct(data, key)
            if ctx.cleanup.dead then root:Destroy(); error("Asset construction cancelled: " .. key) end
            root.Archivable = true; self.cache[key] = root; scope:add(root)
        end
        return self.cache[key]:Clone()
    end
    function module:destroy() scope:destroy(); self.cache = {} end
    return module
end
