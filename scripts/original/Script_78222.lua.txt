local events = game.ReplicatedStorage:WaitForChild("AnimationManager").LocalScriptAPI

local animator = require(game.ReplicatedStorage.AnimationManager)

function events.PlayAnimation.OnServerInvoke(player, KeyframeSequence, character)
	return animator.PlayAnimation(KeyframeSequence, character)
end

events.ChangeAnimationSpeed.OnServerEvent:Connect(function(player, AsamiAnimation, speed)
	animator.ChangeAnimationSpeed(AsamiAnimation, speed)
end)

events.StopAnimationOnHumanoid.OnServerEvent:Connect(function(player, humanoid)
	animator.StopAnimationOnHumanoid(humanoid)
end)