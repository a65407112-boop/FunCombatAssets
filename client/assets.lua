return function(ctx)
    local module = {cache = {}, warnings = {}, pending = {}}
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
    -- Accept earlier exported data too. Internal XML names are not writable
    -- Luau members; preserve both endpoints through the public WeldConstraint API.
    local referenceAliases = {WeldConstraint = {Part0Internal = "Part0", Part1Internal = "Part1"}}
    local nativeSurfaceProperties = {ColorMap=true,ColorMapContent=true,NormalMap=true,NormalMapContent=true,
        MetalnessMap=true,MetalnessMapContent=true,RoughnessMap=true,RoughnessMapContent=true,TexturePack=true,TexturePackContent=true}

    function module:originalMesh(node, key)
        local dependency = ctx.catalog.nativeMeshes
        local surface = dependency and dependency.surfaces and dependency.surfaces[tostring(node.id)]
        local meshId = surface and surface.meshId or tostring(node.id)
        local name = dependency and dependency.nodes and dependency.nodes[meshId]
        assert(name, "Original native " .. node.class .. " dependency is missing from the catalog: " .. key .. "/" .. node.name)
        local replicated = game:GetService("ReplicatedStorage")
        local folder = replicated:FindFirstChild(dependency.folder) or replicated:WaitForChild(dependency.folder, ctx.config.Timeout)
        assert(folder and folder:IsA("Folder"), "Original native mesh folder did not replicate within " .. ctx.config.Timeout
            .. " seconds: ReplicatedStorage/" .. dependency.folder .. " (" .. key .. ")")
        local template = folder:FindFirstChild(name) or folder:WaitForChild(name, ctx.config.Timeout)
        assert(template and template:IsA("MeshPart"), "Original MeshPart did not replicate: ReplicatedStorage/" .. dependency.folder .. "/" .. name .. " (" .. key .. "/" .. node.name .. ")")
        if node.class == "SurfaceAppearance" then
            assert(surface, "Original SurfaceAppearance dependency is missing: " .. key .. "/" .. node.name)
            template = template:FindFirstChild(surface.name) or template:WaitForChild(surface.name, ctx.config.Timeout)
            assert(template and template:IsA("SurfaceAppearance"), "Original SurfaceAppearance did not replicate: ReplicatedStorage/"
                .. dependency.folder .. "/" .. name .. "/" .. surface.name .. " (" .. key .. ")")
        end
        local copy = assert(template:Clone(), "Original native " .. node.class .. " is not Archivable: " .. key .. "/" .. node.name)
        copy:ClearAllChildren()
        return copy
    end

    function module:originalUnion(node, key)
        local dependency = ctx.catalog.nativeCSG
        local name = dependency and dependency.nodes and dependency.nodes[tostring(node.id)]
        assert(name, "Original native UnionOperation dependency is missing from the catalog: " .. key .. "/" .. node.name)
        local replicated = game:GetService("ReplicatedStorage")
        local folder = replicated:FindFirstChild(dependency.folder) or replicated:WaitForChild(dependency.folder, ctx.config.Timeout)
        assert(folder and folder:IsA("Folder"), "Original native CSG folder did not replicate within " .. ctx.config.Timeout
            .. " seconds: ReplicatedStorage/" .. dependency.folder .. " (" .. key .. ")")
        local template = folder:FindFirstChild(name) or folder:WaitForChild(name, ctx.config.Timeout)
        assert(template and template:IsA("UnionOperation"), "Original UnionOperation did not replicate: ReplicatedStorage/"
            .. dependency.folder .. "/" .. name .. " (" .. key .. "/" .. node.name .. ")")
        local copy = assert(template:Clone(), "Original UnionOperation is not Archivable: " .. key .. "/" .. node.name)
        -- Only opaque, original native CSG data comes from the server. All child
        -- Instances, properties, joints and references are restored externally.
        copy:ClearAllChildren()
        return copy
    end

    function module:construct(data, key)
        local byId, made = {}, {}
        local ok, err = pcall(function()
            for _, node in ipairs(data.nodes) do
                local cls = node.class
                if cls == "Script" or cls == "LocalScript" or cls == "ModuleScript" or cls == "RemoteEvent" or cls == "RemoteFunction" then error("Unexpected executable/network asset " .. key) end
                local object
                if cls == "MeshPart" or cls == "SurfaceAppearance" then
                    -- Native cloning preserves immutable mesh initialization
                    -- and protected processed PBR content on every executor.
                    object = self:originalMesh(node, key)
                elseif cls == "UnionOperation" then
                    object = self:originalUnion(node, key)
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
                        local retainedNative = (node.class == "SurfaceAppearance" and nativeSurfaceProperties[name]) or (node.class == "MeshPart"
                            and (name == "MeshId" or name == "MeshContent" or name == "InitialSize"))
                        if prop.type ~= "Ref" and not skip[name] and not retainedNative then
                            local applied, why = pcall(function() object[name] = decode(prop, object, name) end)
                            if not applied then
                                if critical[name] then error(key .. ": " .. node.class .. "." .. name .. ": " .. tostring(why)) end
                                warnOnce(node.class .. "." .. name, "Skipped unsupported/read-only property " .. node.class .. "." .. name)
                            end
                        end
                    end
                    for name, value in pairs(node.attributes or {}) do pcall(function() object:SetAttribute(name, value) end) end
                end
            end
            for _, node in ipairs(data.nodes) do
                local object = byId[node.id]
                if object then
                    if node.parent then object.Parent = byId[node.parent] end
                    for name, prop in pairs(node.properties) do
                        if prop.type == "Ref" then
                            local publicName = referenceAliases[node.class] and referenceAliases[node.class][name] or name
                            local success, why = pcall(function() object[publicName] = prop.value and byId[prop.value] or nil end)
                            if not success and prop.value then error(key .. " reference " .. name .. ": " .. tostring(why)) end
                        end
                    end
                end
            end
        end)
        if not ok then for _, object in ipairs(made) do pcall(function() object:Destroy() end) end; error(err) end
        return assert(byId[data.root], "Missing root in asset " .. key)
    end
    function module:applyImported(data,key,root)
        local marker=assert(ctx.catalog.nativeNodeAttribute,"Original model node marker is missing from the external catalog")
        local all=root:GetDescendants();all[#all+1]=root
        local byId={}
        for _,object in ipairs(all) do
            local id=object:GetAttribute(marker)
            assert(type(id)=="number" and not byId[id],"Original import node ID missing/duplicated: "..key)
            byId[id]=object
        end
        for _,node in ipairs(data.nodes) do
            local object=assert(byId[node.id],"Original import node is missing: "..key.."/"..node.name)
            assert(object.ClassName==node.class and object.Name==node.name,"Original import node class/name differs: "..key.."/"..node.name)
            assert(not node.parent or object.Parent==byId[node.parent],"Original import hierarchy differs: "..key.."/"..node.name)
            for name,prop in pairs(node.properties) do
                local immutable=(node.class=="SurfaceAppearance" and nativeSurfaceProperties[name]) or (node.class=="MeshPart" and (name=="MeshId" or name=="MeshContent" or name=="InitialSize"))
                if not skip[name] and not immutable then
                    local applied,why=pcall(function()
                        if prop.type=="Ref" then
                            local publicName=referenceAliases[node.class] and referenceAliases[node.class][name] or name
                            object[publicName]=prop.value and assert(byId[prop.value],"Original import reference missing") or nil
                        else object[name]=decode(prop,object,name) end
                    end)
                    if not applied then
                        if critical[name] or (prop.type=="Ref" and prop.value) then error(key..": imported "..node.class.."."..name..": "..tostring(why)) end
                        warnOnce(node.class.."."..name,"Skipped unsupported/read-only property "..node.class.."."..name)
                    end
                end
            end
            object:SetAttribute(marker,nil)
        end
    end
    function module:deserialize(entry,key,data)
        local assetFunction=getcustomasset or getsynasset
        assert(type(writefile)=="function" and type(assetFunction)=="function",
            "Original native model in "..key.." requires writefile and getcustomasset/getsynasset on this executor")
        local path="funcombat_"..ctx.manifest.buildId.."_"..key:gsub("[^%w_]","_")..".rbxmx"
        writefile(path,ctx.http(entry.modelPath))
        local done,result,failure=false,nil,nil
        local timedOut=false
        coroutine.wrap(function()
            local ok,objects=pcall(function()
                local asset=assetFunction(path)
                if type(getobjects)=="function" then return getobjects(asset) end
                return game:GetObjects(asset)
            end)
            if ok then
                if timedOut or ctx.cleanup.dead then
                    for _,object in ipairs(objects or {}) do pcall(function() object:Destroy() end) end
                else result=objects end
            else failure=objects end
            done=true
        end)()
        local deadline=tick()+ctx.config.Timeout
        repeat wait(0.05) until done or tick()>=deadline or ctx.cleanup.dead
        timedOut=not done
        if type(delfile)=="function" then pcall(delfile,path) end
        assert(done and not failure and type(result)=="table",
            "Original model deserialization failed for "..key..": "..tostring(failure or "timeout; executor must support local .rbxmx in GetObjects"))
        if #result~=1 then
            for _,object in ipairs(result) do object:Destroy() end
            error("Original model returned "..#result.." roots: "..key)
        end
        local root=result[1]
        local objects=root:GetDescendants();objects[#objects+1]=root
        for _,object in ipairs(objects) do
            if object:IsA("LuaSourceContainer") or object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
                root:Destroy();error("Unexpected executable in presentation model: "..key)
            end
        end
        if #objects~=entry.count then root:Destroy();error("Original model node count differs: "..key) end
        if data and ctx.catalog.nativeNodeAttribute then
            local valid,why=pcall(self.applyImported,self,data,key,root)
            if not valid then root:Destroy();error(why) end
        end
        return root
    end
    function module:checkCapabilities()
        if ctx.catalog.nativeMode ~= "external" then return true end
        assert(type(writefile)=="function" and (type(getcustomasset)=="function" or type(getsynasset)=="function"),
            "This external-resource build requires writefile and getcustomasset/getsynasset plus local model support in GetObjects; no native presentation copy is stored on the server")
        return true
    end
    function module:clone(key)
        if self.pending[key] then
            local deadline=tick()+ctx.config.Timeout*2+1
            repeat wait(0.05) until not self.pending[key] or tick()>=deadline or ctx.cleanup.dead
            assert(not self.pending[key],"Concurrent asset load timed out: "..key)
        end
        if not self.cache[key] then
            local entry = assert(ctx.catalog.packages[key], "Missing asset manifest entry: " .. tostring(key))
            self.pending[key]=true
            local ok,root=pcall(function()
                local data=ctx.json(entry.path)
                assert(not ctx.cleanup.dead,"Asset load cancelled: "..key)
                assert(data.version==1 and #data.nodes==entry.count,"Invalid asset package: "..key)
                if ctx.catalog.nativeMode=="external" and entry.backend=="model" then
                    self:checkCapabilities()
                    return self:deserialize(entry,key,data)
                end
                if entry.backend=="model" then
                    local dependencies=ctx.catalog.nativeCSG and ctx.catalog.nativeCSG.nodes
                    local native=dependencies~=nil
                    for _,node in ipairs(data.nodes) do
                        if node.class=="UnionOperation" and not (dependencies and dependencies[tostring(node.id)]) then native=false end
                    end
                    if not native then return self:deserialize(entry,key) end
                end
                -- Imported costumes include their original model file but have
                -- no immutable mesh/PBR dependencies in this server build.
                if entry.origin=="user-created costume" then
                    for _,node in ipairs(data.nodes) do
                        if node.class=="MeshPart" or node.class=="SurfaceAppearance" then
                            assert(entry.modelPath,"Imported original model is missing: "..key)
                            return self:deserialize(entry,key)
                        end
                    end
                end
                return self:construct(data,key)
            end)
            self.pending[key]=nil
            if not ok then error(root) end
            if ctx.cleanup.dead then root:Destroy(); error("Asset construction cancelled: " .. key) end
            root.Archivable = true; self.cache[key] = root; scope:add(root)
        end
        return self.cache[key]:Clone()
    end
    function module:destroy() scope:destroy(); self.cache = {} end
    return module
end
