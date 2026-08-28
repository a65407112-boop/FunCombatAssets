local Manager = {}
local M = require(script.RagdollModule) 


--- Call this module directely if u wanna ragdoll from server
function Manager:Ragdoll(Duration)
	M.Ragdoll(self,Duration)
	if not game.Players:GetPlayerFromCharacter(self) then
		local Hum = self:FindFirstChildWhichIsA("Humanoid")
		Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
		Hum:ChangeState(Enum.HumanoidStateType.Physics)
		
		if Duration then
		task.delay(Duration,function()				
		Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
		Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
			
			end)
		end
	
		else
		game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ragdoll"):FireClient(game.Players:GetPlayerFromCharacter(self),true)
	end
end

function Manager:UnRagdoll(duration)
	M.UnRagdoll(self)
	
	local Hum = self:FindFirstChildWhichIsA("Humanoid")
	Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
	Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
	
end

return Manager
