-- Keep the source R6 combat body, with the user's actual head/face/accessories.
-- Generate the actual head on a fresh native R6 avatar, then attach it without
-- copying the classic template's mesh, decal or render state onto it.
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
local function animationId(value)
    if type(value)~="string" then return 0 end
    return tonumber(value:match("id=(%d+)") or value:match("(%d+)$")) or 0
end
local function animateMarker(character)
    local animate=character:FindFirstChild("Animate")
    if animate then
        assert(animate:IsA("LocalScript"),"Character Animate is not a LocalScript")
        local marker=animate:FindFirstChild("FunCombatFacialBridge")
        if marker and marker:IsA("BoolValue") and marker.Value then animate:SetAttribute("FunCombatFacialBridge",true) end
    else
        animate=Instance.new("LocalScript");animate.Name="Animate"
        animate:SetAttribute("FunCombatFacialBridge",true);animate.Parent=character
    end
    return animate
end
local function nativeMood(root)
    local animate=root:FindFirstChild("Animate")
    local mood=animate and animate:FindFirstChild("mood") or root:FindFirstChild("mood",true)
    return mood and mood:IsA("StringValue") and mood or nil
end
local function copyMood(source)
    assert(source and source:IsA("StringValue"),"The original mood package has no mood StringValue")
    local mood=Instance.new("StringValue");mood.Name="mood";mood.Value=source.Value
    local first=0
    for _,child in ipairs(source:GetChildren()) do
        if child:IsA("Animation") then
            local id=animationId(child.AnimationId)
            if id>0 then
                local animation=child:Clone()
                -- Avatar packages are data. Never copy executable descendants
                -- from a hosted mood into a live character.
                for _,nested in ipairs(animation:GetDescendants()) do
                    if not nested:IsA("NumberValue") then nested:Destroy() end
                end
                animation.Parent=mood;if first==0 then first=id end
            end
        end
    end
    if first==0 then mood:Destroy();error("The original mood package has no playable Animation reference") end
    return mood,first
end
local function loadMood(character,description,fromHead,valid)
    if not dynamic(character:FindFirstChild("Head")) then return end
    local animate=animateMarker(character)
    local source=fromHead or animate:FindFirstChild("mood")
    local mood,id
    if source and source:IsA("StringValue") then
        mood,id=copyMood(source)
    else
        local assetId=tonumber(description.MoodAnimation) or 0
        if assetId==0 then return end
        local ok,service=pcall(function() return game:GetService("AssetService") end)
        local method
        if ok then pcall(function() method=service.LoadAssetAsync end) end
        if type(method)~="function" then
            service=game:GetService("InsertService");method=service.LoadAsset
        end
        local loaded,asset=pcall(method,service,assetId)
        if not loaded then error("Original mood package "..assetId.." could not load: "..tostring(asset)) end
        if not valid() then asset:Destroy();return end
        local copied,why=pcall(function() mood,id=copyMood(nativeMood(asset)) end)
        asset:Destroy()
        if not copied then error("Original mood package "..assetId..": "..tostring(why)) end
    end
    if not valid() then mood:Destroy();return end
    local previous=animate:FindFirstChild("mood")
    if previous then previous:Destroy() end
    mood.Parent=animate
    character:SetAttribute("FunCombatMoodClipId",id)
end
local function headAttachment(head,other)
    for _,attachment in ipairs(other:GetChildren()) do
        if attachment:IsA("Attachment") and not attachment:IsA("Bone") then
            local target=head:FindFirstChild(attachment.Name)
            if target and target:IsA("Attachment") and not target:IsA("Bone") then return target.CFrame end
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
        if attachment:IsA("Attachment") and not attachment:IsA("Bone") then
            local target=head:FindFirstChild(attachment.Name)
            if target and target:IsA("Attachment") and not target:IsA("Bone") then attachments[attachment]=target end
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
        -- Bone inherits Attachment. Keep only gameplay attachment descendants;
        -- detached old facial bones die with the old head, or return on rollback.
        for _,attachment in ipairs(old:GetChildren()) do
            if attachment:IsA("Attachment") and not attachment:IsA("Bone") then
                for _,nested in ipairs(attachment:GetDescendants()) do
                    if nested:IsA("Bone") then
                        children[#children+1]={object=nested,parent=nested.Parent};nested.Parent=old
                    end
                end
            end
        end
        for _,child in ipairs(old:GetChildren()) do
            local attachment=child:IsA("Attachment") and not child:IsA("Bone")
            local target=attachment and head:FindFirstChild(child.Name)
            if target and target:IsA("Attachment") and not target:IsA("Bone") then
                for _,nested in ipairs(child:GetChildren()) do
                    if not nested:IsA("Bone") then
                        children[#children+1]={object=nested,parent=child};nested.Parent=target
                    end
                end
            elseif attachment or child:IsA("ProximityPrompt") or child:IsA("BillboardGui")
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
    local headDescription=description:Clone()
    for _,key in ipairs({"BackAccessory","FaceAccessory","FrontAccessory","HairAccessory","HatAccessory","NeckAccessory","ShouldersAccessory","WaistAccessory"}) do
        pcall(function() headDescription[key]="" end)
    end
    for _,key in ipairs({"Shirt","Pants","GraphicTShirt"}) do pcall(function() headDescription[key]=0 end) end
    for _,child in ipairs(headDescription:GetChildren()) do
        -- Keep modern head-description metadata such as an owned HeadShape.
        -- Unrelated accessory/body descriptions do not belong in a head donor.
        if not (child:IsA("BodyPartDescription") and child.BodyPart==Enum.BodyPart.Head) then child:Destroy() end
    end
    pcall(function() headDescription.UseAvatarSettings=false end)
    local ok,donor=pcall(function()
        return preferredMethod(Players,"CreateHumanoidModelFromDescriptionAsync","CreateHumanoidModelFromDescription")(
            Players,headDescription,Enum.HumanoidRigType.R6)
    end)
    headDescription:Destroy()
    if not ok then error("Native R6 head "..id.." could not load: "..tostring(donor)) end
    if not valid() then donor:Destroy();return end
    local head=donor:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then donor:Destroy();error("Head asset "..id.." returned no usable Head") end
    local mood=nativeMood(donor)
    local moodCopy
    if mood then pcall(function() moodCopy=copyMood(mood) end) end
    local installed,why=pcall(installHead,character,head)
    donor:Destroy()
    if not installed then
        if moodCopy then moodCopy:Destroy() end
        error("Native R6 head "..id.." could not attach: "..tostring(why))
    end
    character:SetAttribute("FunCombatHeadSource","nativeR6")
    return moodCopy
end
local function prepare(player,character,humanoid,userId,playerCharacter)
    local done,safeToBind,complete,cancelled=false,true,false,false
    local failure,phase=nil,"Avatar description"
    local function diagnostic(message)
        -- The external client can arrive after the initialization Error event.
        -- Keep that same message on the actual character for late observers.
        pcall(function() character:SetAttribute("FunCombatAvatarDiagnostic",message or "") end)
    end
    diagnostic(nil)
    pcall(function() character:SetAttribute("FunCombatMoodClipId",0) end)
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
            for _,child in ipairs(description:GetChildren()) do
                if child:IsA("BodyPartDescription") and child.BodyPart~=Enum.BodyPart.Head then
                    -- Removing these entries also resets their skin colors.
                    -- Keep the user's palette while excluding custom bodies.
                    child.AssetId=0;child.Instance=nil
                end
            end
            pcall(function() description.StaticFacialAnimation=false end)
            phase="Avatar appearance";safeToBind=false
            local applied,why=pcall(function()
                animateMarker(character)
                preferredMethod(humanoid,"ApplyDescriptionAsync","ApplyDescription")(humanoid,description)
            end)
            safeToBind=true
            if applied and valid() then
                pcall(function()
                    character:SetAttribute("FunCombatHeadAssetId",description.Head)
                    character:SetAttribute("FunCombatMoodAnimation",description.MoodAnimation)
                end)
                phase="Dynamic head asset "..tostring(description.Head)
                local loaded,headMood=pcall(loadHead,character,description,valid)
                if not loaded then failure=tostring(headMood);headMood=nil end
                if valid() then
                    phase="Original mood package "..tostring(description.MoodAnimation)
                    local facial,why=pcall(loadMood,character,description,headMood,valid)
                    if not facial then failure=(failure and failure.."; " or "")..tostring(why) end
                end
                if headMood then headMood:Destroy() end
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
        local message=phase.." timed out after 8 seconds; "
            ..(safeToBind and "the existing R6 appearance is retained" or "the character must be reinitialized")
        diagnostic(message)
        return safeToBind,message
    end
    diagnostic(failure)
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
