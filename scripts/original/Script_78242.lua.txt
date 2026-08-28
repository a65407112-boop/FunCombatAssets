_G.Admins = {"GuardianWorld","ghuisehgfrshdsrgsdd","Roblox_ovovo"} 

game.Players.PlayerAdded:Connect(function(player)
	for i, v in pairs (_G.Admins) do
		if player.Name == v then
			script.Admin:Clone().Parent = player:WaitForChild("PlayerGui")
		end
	end
end)