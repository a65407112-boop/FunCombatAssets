-- Keep the source R6 combat body, with the user's actual head/face/accessories.
-- A head-only R15 donor preserves genuine FaceControls/Bones on engines which
-- otherwise apply a static R6 version of a dynamic head. The live rig stays R6.
local Players=game:GetService("Players")
local A={}
local function optionalCopy(from,to,key)
    pcall(function() to[key]=from[key] end)
end
local function preferredMethod(object,modern,legacy)
    local ok,method=pcall(function() return object[modern] end)
    if ok and type(method)=="function" then return method end
    return object[legacy]
end
local function dynamic(head)
    return head and head:IsA("BasePart") and head:FindFirstChildOfClass("FaceControls")~=nil
end
local function headAttachment(head,other)
    for _,attachment in ipairs(other:GetChildren()) do
        if attachment:IsA("Attachment") then
            local target=head:FindFirstChild(attachment.Name)
            if target and target:IsA("Attachment") then return target.CFrame end
        end
    end
end
local function installHead(character,donorHead)
    local old=assert(character:FindFirstChild("Head"),"Original R6 Head is missing")
    local head=donorHead:Clone()
    for _,item in ipairs(head:GetDescendants()) do
        if item:IsA("JointInstance") or item:IsA("WeldConstraint") then item:Destroy() end
    end
    head.Name="Head";head.CFrame=old.CFrame
    for _,key in ipairs({"Anchored","CanCollide","CanTouch","CanQuery","Massless","CollisionGroup"}) do optionalCopy(old,head,key) end
    local joints,children,references,attachments,hasNeck={},{},{},{},false
    for _,attachment in ipairs(old:GetChildren()) do
        if attachment:IsA("Attachment") then
            local target=head:FindFirstChild(attachment.Name)
            if target and target:IsA("Attachment") then attachments[attachment]=target end
        end
    end
    for _,joint in ipairs(character:GetDescendants()) do
        if (joint:IsA("JointInstance") or joint:IsA("WeldConstraint")) and (joint.Part0==old or joint.Part1==old) then
            joints[#joints+1]={joint=joint,p0=joint.Part0,p1=joint.Part1,c0=joint:IsA("JointInstance") and joint.C0,
                c1=joint:IsA("JointInstance") and joint.C1}
            if joint:IsA("Motor6D") and joint.Name=="Neck" then hasNeck=true end
        end
        if joint:IsA("Trail") or joint:IsA("Beam") then
            for _,key in ipairs({"Attachment0","Attachment1"}) do
                if attachments[joint[key]] then references[#references+1]={object=joint,key=key,value=joint[key]} end
            end
        end
    end
    if not hasNeck then head:Destroy();error("Original R6 Neck is missing") end
    local ok,why=pcall(function()
        old.Name="FunCombatPreviousHead";head.Parent=character
        for _,record in ipairs(joints) do
            local joint=record.joint
            if record.p0==old then
                joint.Part0=head
                if joint:IsA("JointInstance") and record.p1 and record.p1.Parent and record.p1.Parent:IsA("Accessory") then
                    joint.C0=headAttachment(head,record.p1) or record.c0
                end
            end
            if record.p1==old then
                joint.Part1=head
                if joint:IsA("JointInstance") and record.p0 and record.p0.Parent and record.p0.Parent:IsA("Accessory") then
                    joint.C1=headAttachment(head,record.p0) or record.c1
                end
            end
        end
        -- Carry original gameplay objects across the swap. The classic decal
        -- and SpecialMesh do not cover the genuine animated head.
        for _,child in ipairs(old:GetChildren()) do
            local target=child:IsA("Attachment") and head:FindFirstChild(child.Name)
            if target and target:IsA("Attachment") then
                for _,nested in ipairs(child:GetChildren()) do
                    children[#children+1]={object=nested,parent=child};nested.Parent=target
                end
            elseif child:IsA("Attachment") or child:IsA("ProximityPrompt") or child:IsA("BillboardGui")
                or child:IsA("SurfaceGui") or child:IsA("Sound") or child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") then
                children[#children+1]={object=child,parent=old};child.Parent=head
            end
        end
        for _,record in ipairs(references) do record.object[record.key]=attachments[record.value] end
    end)
    if not ok then
        for _,record in ipairs(joints) do
            pcall(function()
                record.joint.Part0=record.p0;record.joint.Part1=record.p1
                if record.c0 then record.joint.C0=record.c0;record.joint.C1=record.c1 end
            end)
        end
        for _,record in ipairs(children) do record.object.Parent=record.parent end
        for _,record in ipairs(references) do record.object[record.key]=record.value end
        old.Name="Head";head:Destroy();error(why)
    end
    old:Destroy()
    return head
end
local function loadHead(character,description,valid)
    local id=tonumber(description.Head) or 0
    if id==0 or dynamic(character:FindFirstChild("Head")) then return end
    local headDescription=Instance.new("HumanoidDescription")
    for _,key in ipairs({"Head","Face","HeadColor","HeadScale","MoodAnimation","StaticFacialAnimation"}) do
        optionalCopy(description,headDescription,key)
    end
    pcall(function() headDescription.UseAvatarSettings=false end)
    local ok,donor=pcall(function()
        return preferredMethod(Players,"CreateHumanoidModelFromDescriptionAsync","CreateHumanoidModelFromDescription")(
            Players,headDescription,Enum.HumanoidRigType.R15)
    end)
    headDescription:Destroy()
    if not ok then error("Dynamic head asset "..id.." could not load: "..tostring(donor)) end
    if not valid() then donor:Destroy();return end
    local head=donor:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then donor:Destroy();error("Head asset "..id.." returned no usable Head") end
    -- Classic heads remain the native R6 asset. Only real facial rig data is
    -- transplanted; no substitute mesh or invented animation is installed.
    if dynamic(head) then
        local installed,why=pcall(installHead,character,head)
        donor:Destroy()
        if not installed then error("Dynamic head asset "..id.." could not attach to R6: "..tostring(why)) end
    else donor:Destroy() end
end
local function prepare(player,character,humanoid,userId,playerCharacter)
    local done,safeToBind,complete,cancelled=false,true,false,false
    local failure,phase=nil,"Avatar description"
    local function valid()
        return not cancelled and player.Parent and character.Parent and humanoid.Health>0
            and (not playerCharacter or player.Character==character)
    end
    coroutine.wrap(function()
        local ok,description=pcall(function()
            return preferredMethod(Players,"GetHumanoidDescriptionFromUserIdAsync","GetHumanoidDescriptionFromUserId")(Players,userId)
        end)
        if not valid() then if ok then pcall(function() description:Destroy() end) end;done=true;return end
        if ok then
            for _,key in ipairs({"LeftArm","LeftLeg","RightArm","RightLeg","Torso"}) do description[key]=0 end
            pcall(function() description.StaticFacialAnimation=false end)
            phase="Avatar appearance";safeToBind=false
            local applied,why=pcall(function()
                preferredMethod(humanoid,"ApplyDescriptionAsync","ApplyDescription")(humanoid,description)
            end)
            safeToBind=true
            if applied and valid() then
                pcall(function()
                    character:SetAttribute("FunCombatHeadAssetId",description.Head)
                    character:SetAttribute("FunCombatMoodAnimation",description.MoodAnimation)
                end)
                phase="Dynamic head asset "..tostring(description.Head)
                local loaded,headError=pcall(loadHead,character,description,valid)
                if not loaded then failure=tostring(headError) end
            elseif not applied then failure="Original R6 avatar appearance failed: "..tostring(why) end
            pcall(function() description:Destroy() end)
        else failure="Original avatar description unavailable: "..tostring(description) end
        complete=valid();done=true
    end)()
    local deadline=tick()+8
    repeat wait(0.05) until done or tick()>=deadline or not valid()
    if not valid() then cancelled=true;return false end
    if not done then
        cancelled=true
        -- A late isolated donor/fetch cannot mutate an already bound body.
        -- An engine ApplyDescription still in flight must finish on a discarded
        -- character, since its engine side effects cannot be cancelled by Luau.
        return safeToBind,phase.." timed out after 8 seconds; "
            ..(safeToBind and "the existing R6 appearance is retained" or "the character must be reinitialized")
    end
    return complete,failure
end
function A.prepare(player,character,humanoid)
    return prepare(player,character,humanoid,player.UserId,true)
end
function A.prepareDummy(owner,character,humanoid,userId)
    humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
    return prepare(owner,character,humanoid,userId,false)
end
return A
