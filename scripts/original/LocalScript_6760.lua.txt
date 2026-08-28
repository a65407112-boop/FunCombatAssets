
local player = game.Players.LocalPlayer
local Remote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ragdoll")
local RagdollForce = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RagdollForce")
local OnDeath = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OnDeath")
local Char = player.Character or player.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

Remote.OnClientEvent:Connect(function(toggle)
	if Hum.Health > 0 then
		if toggle then
			Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
			Hum:ChangeState(Enum.HumanoidStateType.Physics)
			Hum.AutoRotate = false
		else
			Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
			Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
			Hum.AutoRotate = true
		end
		--Hum.AutoRotate = false

		--if duration then
		--task.delay(duration,function()				
		--	Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
		--	Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		--	Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
	 --       -- Hum.AutoRotate = true
		--	end)
		--	end
	end
end)

RagdollForce.OnClientEvent:Connect(function()
	warn("RAGDOLL FORCE")
	local Force = Instance.new("LinearVelocity",Root:FindFirstChild("ForceAttachment"))
	Force.Attachment0 = Root:FindFirstAncestor("ForceAttachment")
	Force.RelativeTo = Enum.ActuatorRelativeTo.World
	Force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Force.MaxForce = math.huge
	Force.VectorVelocity = Root.CFrame.LookVector * 5
	Force.Enabled = true
	game.Debris:AddItem(Force,0.1)	

end)

Hum.Died:Connect(function()
	OnDeath:FireServer(Char)	 
end)


