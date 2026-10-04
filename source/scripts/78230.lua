local players = game:GetService("Players")
players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		repeat task.wait() until character.Parent == workspace

		local infoClone = script.Info:Clone()
		infoClone.Parent = character:WaitForChild("Head")
		infoClone.Adornee = character:WaitForChild("Head")
		infoClone.NameText.Text = player.DisplayName
		infoClone.NameText.Background.Text = player.DisplayName

		if player:GetAttribute("Gender") then
			infoClone.GenderText.Text = player:GetAttribute("Gender")
			infoClone.GenderText.Background.Text = player:GetAttribute("Gender")

			if player:GetAttribute("Gender") == "Female" then
				infoClone.GenderText.TextColor3 = Color3.fromRGB(170, 86, 162)
				infoClone.GenderText.Background.TextColor3 = Color3.fromRGB(35, 23, 34)
			elseif player:GetAttribute("Gender") == "Male" then
				infoClone.GenderText.TextColor3 = Color3.fromRGB(27, 175, 158)
				infoClone.GenderText.Background.TextColor3 = Color3.fromRGB(26, 42, 53)
			elseif player:GetAttribute("Gender") == "Fembxy" then
				infoClone.GenderText.TextColor3 = Color3.fromRGB(72, 0, 130)
				infoClone.GenderText.Background.TextColor3 = Color3.fromRGB(26, 42, 53)
			end
		end
		
		local m1_count = 0
		
	end)
end)

local replicatedStorage = game:GetService("ReplicatedStorage")
local setInfoEvent = replicatedStorage.AttributeSystem.SetInfo
setInfoEvent.OnServerEvent:Connect(function(player, infoType, value)
	if not player.Character or not player.Character:FindFirstChild("Head"):FindFirstChild("Info") then return end
	if infoType == "Gender" then
		player:SetAttribute("Gender", value)

		local infoUi = player.Character:FindFirstChild("Head"):FindFirstChild("Info")
		local genderText = infoUi.GenderText.Text
		infoUi.GenderText.Text = value
		infoUi.GenderText.Background.Text = value

		if value == "Female" then
			infoUi.GenderText.TextColor3 = Color3.fromRGB(170, 86, 162)
			infoUi.GenderText.Background.TextColor3 = Color3.fromRGB(35, 23, 34)
		elseif value == "Male" then
			infoUi.GenderText.TextColor3 = Color3.fromRGB(27, 175, 158)
			infoUi.GenderText.Background.TextColor3 = Color3.fromRGB(26, 42, 53)
		elseif player:GetAttribute("Gender") == "Fembxy" then
			infoUi.GenderText.TextColor3 = Color3.fromRGB(72, 0, 130)
			infoUi.GenderText.Background.TextColor3 = Color3.fromRGB(26, 42, 53)
		end
	end
end)