local rs = game:GetService("ReplicatedStorage")
local CombatFunctions = require(rs:WaitForChild("CombatFunctions"))

local resetBindable = Instance.new("BindableEvent")

function removeLeftoverAnimation(player)
	local animatorFolder = game.Workspace:FindFirstChild("AnimatorFolder")
	local workspacePlayer = game.Workspace:FindFirstChild(player.Name)
	if(animatorFolder) then
		for i,v in pairs(animatorFolder:GetChildren()) do
			local target = v:FindFirstChild("Target")
			local stringValue = tostring(target.Value)
			if(stringValue == tostring(player.Name)) or target.Value == nil then
				v:Destroy()
			end
		end
	end
end

function fixPlayers(playerName)
	for _,current_player in game.Players:GetPlayers() do

		local carrying = current_player.Character:GetAttribute("carrying")
		local carriedBy = current_player.Character:GetAttribute("carriedBy")

		warn(carrying)
		warn(carriedBy)

		if(carrying or carriedBy) then
			if(carrying == playerName or carriedBy == playerName) then

				local killstreak = current_player.leaderstats.Killstreak.Value 
				warn(killstreak)
				wait(0.2)

				current_player:LoadCharacter()

				wait(0.5)
				current_player.leaderstats.Killstreak.Value = killstreak 

				if(killstreak and killstreak >= 5) then
					CombatFunctions:awaken(current_player.Character)
				end	
			end
		end 
	end
end

game.Players.PlayerRemoving:Connect(function(removed)
	removeLeftoverAnimation(removed) -- should be it so teamtest
	fixPlayers(removed.Name)
	--Better modules so it gets more clean; alrighty Team test! yea
end)