local Remote = game.ReplicatedStorage.RemoteEvents.UIRemote

local Players = game:GetService("Players")

local function get_player(name: string): Player | nil
	name = name:lower()

	for _, player in ipairs(Players:GetPlayers()) do
		if name == player.Name:lower():sub(1, #name) then
			return player
		end
	end
	return nil
end

Remote.OnServerEvent:Connect(function(Player, TargetedPLR, Type)
	if Type == "Kick" then
		get_player(TargetedPLR):Kick("You've been Kicked by an Admin")
	elseif Type == "Kill" then
		get_player(TargetedPLR).Character.Humanoid.Health = 0
	elseif Type == "NoRespawn" then
		get_player(TargetedPLR).Character:Destroy()
	end
end)