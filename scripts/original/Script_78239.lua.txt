game.Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg)
		if msg == "/e secretdoor" then
			if game.Workspace:FindFirstChild("Crossroads") then
				local crossroads = game.Workspace:FindFirstChild("Crossroads")
				if crossroads ~= nil then
					if crossroads.SecretDoor.CanCollide == true then
						crossroads.SecretDoor.CanCollide = false
						else
						crossroads.SecretDoor.CanCollide = true
					end
				end
			end
		end
	end)
end)