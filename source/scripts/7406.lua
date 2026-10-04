local Ragdoll = {}
function Ragdoll:Ragdoll(Duration)
	self:SetAttribute("ragdolled", true)
	for i,v in pairs(self:GetDescendants()) do
		if v:IsA("Motor6D")  then
			local Attachment1 = Instance.new("Attachment")
			Attachment1.Name = "RagdollAttach"
			local Attachment2 = Instance.new("Attachment")
			Attachment2.Name = "RagdollAttach"
			
			Attachment1.CFrame = v.C0
			Attachment2.CFrame = v.C1
			Attachment1.Parent = v.Part0
			Attachment2.Parent = v.Part1
			
			local Socket = Instance.new("BallSocketConstraint")
			Socket.Attachment0 = Attachment1
			Socket.Attachment1 = Attachment2
			Socket.LimitsEnabled = true
			Socket.TwistLimitsEnabled = true
			Socket.MaxFrictionTorque = 30
			Socket.Restitution = 0.5
			--Socket.UpperAngle = 25			
			if v.Name == "Right Shoulder" or v.Name == "Left Shoulder" then
				--Socket.TwistUpperAngle = -30
			end
			Socket.Parent = v.Parent
			
			v.Enabled = false
			
			if Duration then 
				task.delay(Duration,function()
					Ragdoll.UnRagdoll(self)
				end)
			end
			
		end
	end
	
	if Duration then
		task.delay(Duration,function()
			Ragdoll.UnRagdoll(self)
		end)
	end
end

function Ragdoll:UnRagdoll()
	self:SetAttribute("ragdolled", false)
	for i,v in pairs(self:GetDescendants()) do
		if  v.Name == "RagdollAttach" or v:IsA("BallSocketConstraint") then
			v:Destroy()
		elseif v:IsA("Motor6D") then
			v.Enabled = true
		end
	end
	
	--warn("GOT UP")
	
	local Hum = self:FindFirstChildWhichIsA("Humanoid")
	Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
	Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
	
	if game:GetService("Players"):GetPlayerFromCharacter(self) then
		game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ragdoll"):FireClient(game.Players:GetPlayerFromCharacter(self),false)
	end
end
return Ragdoll
