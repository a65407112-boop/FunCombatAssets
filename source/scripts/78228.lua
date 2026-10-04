local players = game.Players
players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local HumanoidDesc = players:GetHumanoidDescriptionFromUserId(player.UserId)
		HumanoidDesc.Head = 0
		HumanoidDesc.LeftArm = 0
		HumanoidDesc.LeftLeg = 0
		HumanoidDesc.RightArm = 0
		HumanoidDesc.RightLeg = 0
		HumanoidDesc.Torso = 0
		char:FindFirstChildWhichIsA("Humanoid"):ApplyDescription(HumanoidDesc)
		wait() --Wait for desc to apply
		char.HumanoidRootPart.Anchored = false
	end)
end)

local rlc  = game:GetService("ReplicatedStorage").Remotes.ReloadCharacter

rlc.OnServerEvent:Connect(function(plr)
	print(plr)
	-- In case this does not work, we can try checking if the plr is matching for that set of problems @-@ -- well we'll see if it works or nah
	--plr:LoadCharacter()
end)