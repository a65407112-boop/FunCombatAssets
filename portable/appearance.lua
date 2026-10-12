local A={}
local aliases={Head={"Head"},Torso={"Torso","UpperTorso","LowerTorso"},["Left Arm"]={"Left Arm","LeftUpperArm","LeftLowerArm"},
    ["Right Arm"]={"Right Arm","RightUpperArm","RightLowerArm"},["Left Leg"]={"Left Leg","LeftUpperLeg","LeftLowerLeg"},["Right Leg"]={"Right Leg","RightUpperLeg","RightLowerLeg"}}
local colorFields={Head="HeadColor3",Torso="TorsoColor3",["Left Arm"]="LeftArmColor3",["Right Arm"]="RightArmColor3",["Left Leg"]="LeftLegColor3",["Right Leg"]="RightLegColor3"}
function A.color(source,name,fallback)
    local colors=source:FindFirstChildOfClass("BodyColors")
    if colors then local ok,value=pcall(function()return colors[colorFields[name]]end);if ok and value~=nil then return value end end
    for _,alias in ipairs(aliases[name] or {}) do
        local part=source:FindFirstChild(alias)
        if part then local ok,value=pcall(function()return part.Color end);if ok and value~=nil then return value end end
    end
    return fallback
end
function A.current(source,getCurrent)return source.Parent~=nil and (not getCurrent or getCurrent()==source)end
function A.affects(object,source)
    local class=object.ClassName
    if class=="Accessory" or class=="Shirt" or class=="Pants" or class=="ShirtGraphic" or class=="BodyColors" then return true end
    if object.Name=="Head" and object.Parent==source then return true end
    local head=source:FindFirstChild("Head")
    return head~=nil and (class=="Decal" or class=="SurfaceAppearance") and object.Parent==head
end
return A
