-- Reconstruct the two distinct source rigs; no saved NPC Model is required.
local F={}
local reported={}
local allowed={Model=true,Part=true,Humanoid=true,Motor6D=true,Weld=true,WeldConstraint=true,
    Attachment=true,SpecialMesh=true,BodyColors=true,Decal=true,BoolValue=true,StringValue=true,NumberValue=true,IntValue=true,Folder=true}
local skip={Name=true,Parent=true,ScaleFactor=true,NeedsPivotMigration=true,Origin=true,WorldPivot=true,
    RootPart=true,WalkToPart=true,MoveDirection=true,SeatPart=true,FloorMaterial=true,AssemblyLinearVelocity=true,AssemblyAngularVelocity=true}
local critical={CFrame=true,Size=true,Color=true,Transparency=true,Anchored=true,CanCollide=true,CanTouch=true,
    MaxHealth=true,Health=true,WalkSpeed=true,JumpPower=true,Part0=true,Part1=true,C0=true,C1=true,PrimaryPart=true,MeshId=true,TextureId=true,Texture=true}
local function decode(prop,object,key)
    local t,v=prop.type,prop.value
    if t=='Ref' then return nil end
    if t=='string' or t=='bool' or t=='number' or t=='int' or t=='int64' then return v end
    if t=='Vector3' then return Vector3.new(unpack(v)) end
    if t=='CFrame' then return CFrame.new(unpack(v)) end
    if t=='Color3' then return Color3.new(unpack(v)) end
    if t=='BrickColor' then return BrickColor.new(v) end
    if t=='PhysicalProperties' then return v and PhysicalProperties.new(unpack(v)) or nil end
    if t=='token' then
        local current=object[key]
        if typeof(current)=='EnumItem' then
            for _,item in ipairs(current.EnumType:GetEnumItems()) do if item.Value==v then return item end end
            error('Unsupported rig enum '..key..'='..v)
        end
        return v
    end
    error('Unsupported original rig property type '..t..'/'..key)
end
function F.create(data)
    assert(type(data)=='table' and data.version==1 and type(data.nodes)=='table','Invalid original rig data')
    local objects,made={},{}
    local ok,why=pcall(function()
        for _,node in ipairs(data.nodes) do
            assert(allowed[node.class],'Unexpected original rig class '..tostring(node.class))
            assert(not objects[node.id],'Duplicate original rig node')
            local object=Instance.new(node.class);object.Name=node.name;objects[node.id]=object;made[#made+1]=object
        end
        for _,node in ipairs(data.nodes) do
            local object=objects[node.id]
            -- Maximum health precedes current health on the original Humanoid.
            if node.properties.MaxHealth then object.MaxHealth=node.properties.MaxHealth.value end
            for key,prop in pairs(node.properties) do
                if not skip[key] and prop.type~='Ref' and prop.type~='Color3' then
                    local applied,failure=pcall(function() object[key]=decode(prop,object,key) end)
                    if not applied and critical[key] then error(node.name..'.'..key..': '..tostring(failure)) end
                    if not applied and not reported[node.class..'.'..key] then
                        reported[node.class..'.'..key]=true;warn('Original rig skipped unsupported/read-only property '..node.class..'.'..key)
                    end
                end
            end
            -- Explicit RGB colors follow their derived BrickColor properties.
            for key,prop in pairs(node.properties) do if prop.type=='Color3' then object[key]=decode(prop,object,key) end end
            for key,value in pairs(node.attributes or {}) do object:SetAttribute(key,value) end
        end
        for _,node in ipairs(data.nodes) do
            local object=objects[node.id]
            if node.parent then object.Parent=assert(objects[node.parent],'Missing original rig parent') end
            for key,prop in pairs(node.properties) do
                if prop.type=='Ref' and not skip[key] then
                    local target=prop.value and assert(objects[prop.value],'Missing original rig reference') or nil
                    local applied,failure=pcall(function() object[key]=target end)
                    if not applied and critical[key] then error(node.name..'.'..key..': '..tostring(failure)) end
                end
            end
        end
        assert(objects[data.root] and objects[data.root]:IsA('Model'),'Original rig Model root is missing')
    end)
    if not ok then for _,object in ipairs(made) do pcall(function() object:Destroy() end) end;error(why) end
    return objects[data.root]
end
return F
