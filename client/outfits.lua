-- Optional user-created costumes. This module has no combat or animation actions.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local config = ctx.json("config/outfits.json")
    assert(config.version == 1 and type(config.packages) == "table" and type(config.byGender) == "table", "Invalid costume configuration")
    local records = {}
    local clothes = {Shirt="ShirtTemplate", Pants="PantsTemplate", ShirtGraphic="Graphic"}
    local allowed = {Model=true, Folder=true, Accessory=true, Part=true, MeshPart=true, SpecialMesh=true,
        BlockMesh=true, CylinderMesh=true, Decal=true, Texture=true, Attachment=true, Weld=true,
        WeldConstraint=true, Motor6D=true, Shirt=true, Pants=true, ShirtGraphic=true, SurfaceAppearance=true}
    for slot, entry in pairs(config.packages) do
        assert((slot == "pp" or slot == "boba") and type(entry.path) == "string"
            and entry.path:match("^assets/outfits/") and not entry.path:find("%.%."), "Invalid costume path/slot")
        ctx.catalog.packages["outfits/" .. slot] = entry
    end
    local function all(root)
        local list = {root}
        for _, child in ipairs(root:GetDescendants()) do list[#list+1] = child end
        return list
    end
    local function attachment(character, accessory, handle)
        local mount = accessory:GetAttribute("MountPart")
        if type(mount) == "string" then
            local part = character:FindFirstChild(mount)
            if part and part:IsA("BasePart") and mount ~= "HumanoidRootPart" then
                return part, accessory.AttachmentPoint or CFrame.new(), CFrame.new()
            end
        end
        for _, item in ipairs(handle:GetChildren()) do
            if item:IsA("Attachment") then
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") then
                        local target = part:FindFirstChild(item.Name)
                        if target and target:IsA("Attachment") then return part, target.CFrame, item.CFrame end
                    end
                end
            end
        end
        error("No matching body attachment for " .. accessory.Name .. "; set MountPart or a matching Handle attachment")
    end
    local function mountCostume(character, root, owner)
        local plans, selectedClothes, ours, saved = {}, {}, {}, {}
        for _, item in ipairs(all(root)) do
            assert(allowed[item.ClassName], "Costume contains unsupported class " .. item.ClassName)
            if item:IsA("Accessory") then
                local handle = item:FindFirstChild("Handle")
                assert(handle and handle:IsA("BasePart"), "Costume accessory has no Handle: " .. item.Name)
                local part, c0, c1 = attachment(character, item, handle)
                plans[#plans+1] = {accessory=item, handle=handle, part=part, c0=c0, c1=c1}
            elseif clothes[item.ClassName] then
                selectedClothes[item.ClassName], ours[item] = true, true
            end
        end
        local function hideOriginal(item)
            local property = clothes[item.ClassName]
            if not owner.dead and property and selectedClothes[item.ClassName] and not ours[item] then
                if saved[item] == nil then saved[item] = {property=property, value=item[property]} end
                item[property] = ""
            end
        end
        owner:add(function()
            for item, old in pairs(saved) do
                if item.Parent and item[old.property] == "" then item[old.property] = old.value end
            end
        end)
        for _, child in ipairs(character:GetChildren()) do hideOriginal(child) end
        owner:add(character.ChildAdded:Connect(hideOriginal))
        local torso = character:FindFirstChild("Torso")
        local tinted = {}
        for _, item in ipairs(all(root)) do
            if item:IsA("BasePart") then
                item.Anchored, item.CanCollide, item.Massless = false, false, true
                pcall(function() item.CanTouch = false; item.CanQuery = false end)
                if torso and item:GetAttribute("MatchBodyColor") == true then
                    item.Color = torso.Color; tinted[#tinted+1] = item
                end
            end
        end
        if torso and #tinted > 0 then
            owner:add(torso:GetPropertyChangedSignal("Color"):Connect(function()
                for _, item in ipairs(tinted) do if item.Parent then item.Color = torso.Color end end
            end))
        end
        for _, plan in ipairs(plans) do
            local transform = plan.part.CFrame * plan.c0 * plan.c1:Inverse() * plan.handle.CFrame:Inverse()
            for _, item in ipairs(plan.accessory:GetDescendants()) do
                if item:IsA("BasePart") then item.CFrame = transform * item.CFrame end
            end
            local weld = Instance.new("Weld")
            weld.Name, weld.Part0, weld.Part1 = "AccessoryWeld", plan.part, plan.handle
            weld.C0, weld.C1, weld.Parent = plan.c0, plan.c1, plan.handle
        end
        root.Parent = character
        for item in pairs(ours) do owner:add(item); item.Parent = character end
    end
    local update
    local function remove(character)
        local record = records[character]
        if record then records[character] = nil; record.scope:destroy() end
    end
    update = function(state)
        local character = state.character
        if scope.dead or not character or not character.Parent then return end
        local record = records[character]
        if not record then
            record = {scope=scope:scope(), serial=0}
            records[character] = record
            record.scope:add(character.AncestryChanged:Connect(function(_, parent) if not parent then remove(character) end end))
            record.scope:add(character.DescendantAdded:Connect(function(child)
                if (child:IsA("BasePart") and child.Parent == character)
                    or (child:IsA("Attachment") and child.Parent and child.Parent.Parent == character) then
                    record.failed = nil
                    if record.state then update(record.state) end
                end
            end))
        end
        record.state = state
        local slot = config.byGender[state.gender or ""]
        if not config.packages[slot or ""] then slot = nil end
        if slot and (record.slot == slot or record.loading == slot or record.failed == slot) then return end
        if not slot and not record.slot and not record.loading and not record.failed then return end
        record.serial = record.serial + 1
        local serial = record.serial
        if record.wearing then record.wearing:destroy(); record.wearing = nil end
        record.slot, record.failed, record.loading = nil, nil, slot
        if not slot then return end
        local ok, root = pcall(function() return ctx.assets:clone("outfits/" .. slot) end)
        if record.scope.dead or record.serial ~= serial then
            if ok then root:Destroy() end
            return
        end
        record.loading = nil
        if not ok then record.failed=slot; ctx.report("Costume " .. slot .. ": " .. tostring(root)); return end
        local owner = record.scope:scope()
        owner:add(root)
        local mounted, why = pcall(function()
            assert(root.Name == slot, "Costume root name does not match slot " .. slot)
            mountCostume(character, root, owner)
        end)
        if not mounted then owner:destroy(); record.failed=slot; ctx.report("Costume " .. slot .. ": " .. tostring(why)); return end
        record.wearing, record.slot = owner, slot
    end
    scope:add(ctx.state:onChanged(update))
    scope:add(ctx.network:on("Remove", function(data) remove(data.character) end))
    for _, state in pairs(ctx.state:all()) do update(state) end
    return {destroy=function() scope:destroy(); records={} end}
end
