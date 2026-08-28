script.StopAnimationControl.Disabled = false

local animationIdentifier = Instance.new("ObjectValue")
animationIdentifier.Value = script
animationIdentifier.Name = "CurrentAnimation"
animationIdentifier.Parent = script.Target.Value.Humanoid

function ReplicateAnimationInPlayer(player)
	local newAnimation = script.AnimationPlayer:Clone()
	newAnimation.Parent = player.PlayerGui
	newAnimation.Disabled = false
end

game.Players.PlayerAdded:Connect(ReplicateAnimationInPlayer)

for i, player in pairs(game.Players:GetPlayers()) do
	ReplicateAnimationInPlayer(player)
end