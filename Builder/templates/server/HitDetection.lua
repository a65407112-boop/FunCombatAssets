-- OBB intersection for original hitbox volumes; uses APIs available on older R6 clients.
local H={}
local function axes(frame) return {frame.RightVector,frame.UpVector,-frame.LookVector} end
local function extent(axis,basis,half)
    return math.abs(axis:Dot(basis[1]))*half.X+math.abs(axis:Dot(basis[2]))*half.Y+math.abs(axis:Dot(basis[3]))*half.Z
end
function H.intersects(a,sizeA,b,sizeB)
    local aa,bb=axes(a),axes(b)
    local halfA,halfB=sizeA*0.5,sizeB*0.5
    local delta=b.Position-a.Position
    local tests={aa[1],aa[2],aa[3],bb[1],bb[2],bb[3]}
    for _,x in ipairs(aa) do for _,y in ipairs(bb) do tests[#tests+1]=x:Cross(y) end end
    for _,axis in ipairs(tests) do
        if axis:Dot(axis)>1e-8 and math.abs(delta:Dot(axis))>extent(axis,aa,halfA)+extent(axis,bb,halfB)+1e-5 then return false end
    end
    return true
end
function H.character(frame,size,character)
    for _,part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and H.intersects(frame,size,part.CFrame,part.Size) then return true end
    end
    return false
end
return H
