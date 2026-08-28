local billboardgui = 
	game:GetService("ServerStorage"):WaitForChild("BillboardGui")

game.Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(function(character)

		if player.Name == "DeluxeyThaLux" then
			local clonedgui = billboardgui:Clone()
			clonedgui.TextLabel.Text = "OWNER"
			clonedgui.TextLabel.TextColor3 = Color3.fromRGB(0,0,0)
			clonedgui.Parent = game.Workspace:WaitForChild(player.Name).Head
		end

	end)


end)
