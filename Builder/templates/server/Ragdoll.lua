-- Source socket settings from Manager/RagdollModule, with scoped restoration.
local R = {}
local records = {}
function R.set(character,enabled)
    local old=records[character]
    if enabled and old then return end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if enabled then
        local record={objects={},motors={},platform=humanoid and humanoid.PlatformStand}
        records[character]=record
        for _,joint in ipairs(character:GetDescendants()) do
            if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
                local a,b=Instance.new("Attachment"),Instance.new("Attachment")
                a.Name,b.Name="RagdollAttach","RagdollAttach"
                a.CFrame,b.CFrame=joint.C0,joint.C1
                a.Parent,b.Parent=joint.Part0,joint.Part1
                local socket=Instance.new("BallSocketConstraint")
                socket.Attachment0,socket.Attachment1=a,b
                socket.LimitsEnabled,socket.TwistLimitsEnabled=true,true
                socket.MaxFrictionTorque,socket.Restitution=30,0.5
                socket.Parent=joint.Parent
                record.objects[#record.objects+1]=a;record.objects[#record.objects+1]=b;record.objects[#record.objects+1]=socket
                record.motors[joint]=joint.Enabled;joint.Enabled=false
            end
        end
        if humanoid then humanoid.PlatformStand=true;humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
    elseif old then
        records[character]=nil
        for _,object in ipairs(old.objects) do object:Destroy() end
        for motor,value in pairs(old.motors) do if motor.Parent then motor.Enabled=value end end
        if humanoid then
            humanoid.PlatformStand=old.platform or false
            if humanoid.Health>0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end
end
function R.remove(character) R.set(character,false) end
return R
