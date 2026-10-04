local Animator = {}

local ResumeSpeed = 0

function GetOrSetAnimationFolder()
	local folder = game.Workspace:FindFirstChild("AnimatorFolder")
	if folder then
		return folder
	else
		local newFolder = Instance.new("Folder")
		newFolder.Name = "AnimatorFolder"
		newFolder.Parent = workspace
		return newFolder
	end
end

function Animator.PlayAnimation(KeyframeSequence, character)
	if not KeyframeSequence:IsA("KeyframeSequence") then
		print("not a sequence")
		return
	end
	
	if character.Humanoid:FindFirstChild("CurrentAnimation") then
		Animator.StopAnimation(character.Humanoid.CurrentAnimation.Value)
	end
	
	local newAnimation = script.PlayingAnimation:Clone()
	newAnimation:WaitForChild("Speed").Value = 50
	newAnimation:WaitForChild("Target").Value = character
	newAnimation:WaitForChild("AnimationPlayer"):WaitForChild("Origin").Value = newAnimation
	local newKFS = KeyframeSequence:Clone()
	newKFS.Parent = newAnimation
	newAnimation.AnimationPlayer:WaitForChild("Animation").Value = newKFS
	newAnimation.AnimationPlayer:WaitForChild("Rig").Value = character
	newAnimation.Parent = GetOrSetAnimationFolder()
	newAnimation.Disabled = false
	--warn("PLAYING")
	return newAnimation
end

function Animator.StopAnimation(AsamiAnimation)
	if AsamiAnimation:IsA("Script") and AsamiAnimation:FindFirstChild("StopAnimationControl") then
		AsamiAnimation.StopAnimationControl.OnStopCall:Invoke()
		AsamiAnimation:Destroy()
	end
end

function Animator.ChangeAnimationSpeed(AsamiAnimation, speed)
	if AsamiAnimation:IsA("Script") and AsamiAnimation:FindFirstChild("StopAnimationControl") then
		AsamiAnimation.Speed.Value = speed
	end
end

function Animator.StopAnimationOnHumanoid(humanoid)
	if humanoid:FindFirstChild("CurrentAnimation") then
		Animator.StopAnimation(humanoid.CurrentAnimation.Value)
		local player = game:GetService("Players"):GetPlayerFromCharacter(humanoid.Parent)
		if player then
			player.PlayerGui.AnimationPlayer:Destroy()
		end
	end
end

return Animator