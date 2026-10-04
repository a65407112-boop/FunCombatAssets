function StopAnimation()
	if script.Parent.Target.Value == nil then return end
	if script.Parent.Target.Value.Humanoid then
		if script.Parent.Target.Value.Humanoid:FindFirstChild("CurrentAnimation") then
			script.Parent.Target.Value.Humanoid.CurrentAnimation:Destroy()
		end
	end
	script.Parent.StopAnimation:FireAllClients()
	script.ConfirmDestruction.OnServerEvent:Connect(function()
		script.Parent:Destroy()
	end)
end

script.OnStopCall.OnInvoke = StopAnimation

script.Parent.Target.Value.Humanoid.Died:Connect(StopAnimation)

local player = game.Players:GetPlayerFromCharacter(script.Parent.Target.Value)

if player then
	player.CharacterRemoving:Connect(StopAnimation)
end