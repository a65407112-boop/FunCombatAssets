return {
nodes={
{id=1,c=[[LocalScript]],n=[[Animate]],p=0,pr={
 {[[Disabled]],false},
 {[[LinkedSource]],[[]]},
 {[[RunContext]],0},
 {[[ScriptGuid]],[[{2fb4bdcd-cd49-4274-b766-562055dce1da}]]},
},rf={
}},
{id=2,c=[[StringValue]],n=[[idle]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=3,c=[[Animation]],n=[[Animation1]],p=2,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180435571]]},
},rf={
}},
{id=4,c=[[NumberValue]],n=[[Weight]],p=3,pr={
 {[[Value]],9.0},
},rf={
}},
{id=5,c=[[Animation]],n=[[Animation2]],p=2,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180435792]]},
},rf={
}},
{id=6,c=[[NumberValue]],n=[[Weight]],p=5,pr={
 {[[Value]],1.0},
},rf={
}},
{id=7,c=[[StringValue]],n=[[walk]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=8,c=[[Animation]],n=[[WalkAnim]],p=7,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180426354]]},
},rf={
}},
{id=9,c=[[StringValue]],n=[[run]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=10,c=[[Animation]],n=[[RunAnim]],p=9,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180426354]]},
},rf={
}},
{id=11,c=[[StringValue]],n=[[jump]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=12,c=[[Animation]],n=[[JumpAnim]],p=11,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=125750702]]},
},rf={
}},
{id=13,c=[[StringValue]],n=[[climb]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=14,c=[[Animation]],n=[[ClimbAnim]],p=13,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180436334]]},
},rf={
}},
{id=15,c=[[StringValue]],n=[[toolnone]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=16,c=[[Animation]],n=[[ToolNoneAnim]],p=15,pr={
 {[[AnimationId]],[[rbxassetid://0]]},
},rf={
}},
{id=17,c=[[StringValue]],n=[[fall]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=18,c=[[Animation]],n=[[FallAnim]],p=17,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=180436148]]},
},rf={
}},
{id=19,c=[[StringValue]],n=[[sit]],p=1,pr={
 {[[Value]],[[]]},
},rf={
}},
{id=20,c=[[Animation]],n=[[SitAnim]],p=19,pr={
 {[[AnimationId]],[[http://www.roblox.com/asset/?id=178130996]]},
},rf={
}},
{id=21,c=[[NumberValue]],n=[[ScaleDampeningPercent]],p=1,pr={
 {[[Value]],1.0},
},rf={
}},
{id=22,c=[[LocalScript]],n=[[Leaning]],p=0,pr={
 {[[Disabled]],false},
 {[[LinkedSource]],[[]]},
 {[[RunContext]],0},
 {[[ScriptGuid]],[[{3e1a4370-b152-4d46-a312-da7364b7e061}]]},
},rf={
}},
{id=23,c=[[LocalScript]],n=[[RagOnDeath]],p=0,pr={
 {[[Disabled]],false},
 {[[LinkedSource]],[[]]},
 {[[RunContext]],0},
 {[[ScriptGuid]],[[{c5b8df61-83ff-4314-80d9-8991b9b6af91}]]},
},rf={
}},
{id=24,c=[[LocalScript]],n=[[main]],p=0,pr={
 {[[Disabled]],false},
 {[[LinkedSource]],[[]]},
 {[[RunContext]],0},
 {[[ScriptGuid]],[[{48edd91e-1bca-4c14-befc-163db8a79389}]]},
},rf={
}},
},sources={
[1]={class=[[LocalScript]],source=[[local Figure = script.Parent
local Torso = Figure:WaitForChild("Torso")
local RightShoulder = Torso:WaitForChild("Right Shoulder")
local LeftShoulder = Torso:WaitForChild("Left Shoulder")
local RightHip = Torso:WaitForChild("Right Hip")
local LeftHip = Torso:WaitForChild("Left Hip")
local Neck = Torso:WaitForChild("Neck")
local Humanoid = Figure:WaitForChild("Humanoid")
local pose = "Standing"

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0
local animTable = {}
local animNames = { 
	idle = 	{	
				{ id = "http://www.roblox.com/asset/?id=180435571", weight = 9 },
				{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
			},
	walk = 	{ 	
				{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 } 
			}, 
	run = 	{
				{ id = "run.xml", weight = 10 } 
			}, 
	jump = 	{
				{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 } 
			}, 
	fall = 	{
				{ id = "http://www.roblox.com/asset/?id=180436148", weight = 10 } 
			}, 
	climb = {
				{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 } 
			}, 
	sit = 	{
				{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 } 
			},	
	toolnone = {
				{ id = "http://www.roblox.com/asset/?id=182393478", weight = 10 } 
			},
	toolslash = {
				{ id = "http://www.roblox.com/asset/?id=129967390", weight = 10 } 
--				{ id = "slash.xml", weight = 10 } 
			},
	toollunge = {
				{ id = "http://www.roblox.com/asset/?id=129967478", weight = 10 } 
			},
	wave = {
				{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
			},
	point = {
				{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
			},
	dance1 = {
				{ id = "http://www.roblox.com/asset/?id=182435998", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491037", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491065", weight = 10 } 
			},
	dance2 = {
				{ id = "http://www.roblox.com/asset/?id=182436842", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491248", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491277", weight = 10 } 
			},
	dance3 = {
				{ id = "http://www.roblox.com/asset/?id=182436935", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491368", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491423", weight = 10 } 
			},
	laugh = {
				{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
			},
	cheer = {
				{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
			},
}
local dances = {"dance1", "dance2", "dance3"}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0	
	animTable[name].connections = {}

	-- check for config values
	local config = script:FindFirstChild(name)
	if (config ~= nil) then
--		print("Loading anims " .. name)
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
	--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
				idx = idx + 1
			end
		end
	end

	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
		end
	end
end

-- Setup animation objects
function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end	
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

-- Clear any existing animation tracks
-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if animator then
	local animTracks = animator:GetPlayingAnimationTracks()
	for i,track in ipairs(animTracks) do
		track:Stop(0)
		track:Destroy()
	end
end


for name, fileList in pairs(animNames) do 
	configureAnimationSet(name, fileList)
end	

-- ANIMATION

-- declarations
local toolAnim = "None"
local toolAnimTime = 0

local jumpAnimTime = 0
local jumpAnimDuration = 0.3

local toolTransitionTime = 0.1
local fallTransitionTime = 0.3
local jumpMaxLimbVelocity = 0.75

-- functions

function stopAllAnimations()
	local oldAnim = currentAnim

	-- return to idle if finishing an emote
	if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
		oldAnim = "idle"
	end

	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end

	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	return oldAnim
end

function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		currentAnimTrack:AdjustSpeed(currentAnimSpeed)
	end
end

function keyFrameReachedFunc(frameName)
	if (frameName == "End") then

		local repeatAnim = currentAnim
		-- return to idle if finishing an emote
		if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
			repeatAnim = "idle"
		end
		
		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

-- Preload animations
function playAnimation(animName, transitionTime, humanoid) 
		
	local roll = math.random(1, animTable[animName].totalWeight) 
	local origRoll = roll
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
	local anim = animTable[animName][idx].anim

	-- switch animation		
	if (anim ~= currentAnimInstance) then
		
		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end

		currentAnimSpeed = 1.0
	
		-- load it to the humanoid; get AnimationTrack
		currentAnimTrack = humanoid:LoadAnimation(anim)
		currentAnimTrack.Priority = Enum.AnimationPriority.Core
		 
		-- play the animation
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		-- set up keyframe name triggers
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
		
	end

end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local toolAnimName = ""
local toolAnimTrack = nil
local toolAnimInstance = nil
local currentToolAnimKeyframeHandler = nil

function toolKeyFrameReachedFunc(frameName)
	if (frameName == "End") then
--		print("Keyframe : ".. frameName)	
		playToolAnimation(toolAnimName, 0.0, Humanoid)
	end
end


function playToolAnimation(animName, transitionTime, humanoid, priority)	 
		
		local roll = math.random(1, animTable[animName].totalWeight) 
		local origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
		local anim = animTable[animName][idx].anim

		if (toolAnimInstance ~= anim) then
			
			if (toolAnimTrack ~= nil) then
				toolAnimTrack:Stop()
				toolAnimTrack:Destroy()
				transitionTime = 0
			end
					
			-- load it to the humanoid; get AnimationTrack
			toolAnimTrack = humanoid:LoadAnimation(anim)
			if priority then
				toolAnimTrack.Priority = priority
			end
			 
			-- play the animation
			toolAnimTrack:Play(transitionTime)
			toolAnimName = animName
			toolAnimInstance = anim

			currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
		end
end

function stopToolAnimations()
	local oldAnim = toolAnimName

	if (currentToolAnimKeyframeHandler ~= nil) then
		currentToolAnimKeyframeHandler:disconnect()
	end

	toolAnimName = ""
	toolAnimInstance = nil
	if (toolAnimTrack ~= nil) then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end


	return oldAnim
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------


function onRunning(speed)
	if speed > 0.01 then
		playAnimation("walk", 0.1, Humanoid)
		if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
			setAnimationSpeed(speed / 14.5)
		end
		pose = "Running"
	else
		if emoteNames[currentAnim] == nil then
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end
	end
end

function onDied()
	pose = "Dead"
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / 12.0)
	pose = "Climbing"
end

function onGettingUp()
	pose = "GettingUp"
end

function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

function onFallingDown()
	pose = "FallingDown"
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	pose = "PlatformStanding"
end

function onSwimming(speed)
	if speed > 0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end

function getTool()	
	for _, kid in ipairs(Figure:GetChildren()) do
		if kid.className == "Tool" then return kid end
	end
	return nil
end

function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end

function animateTool()
	
	if (toolAnim == "None") then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if (toolAnim == "Slash") then
		playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if (toolAnim == "Lunge") then
		playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
end

function moveSit()
	RightShoulder.MaxVelocity = 0.15
	LeftShoulder.MaxVelocity = 0.15
	RightShoulder:SetDesiredAngle(3.14 /2)
	LeftShoulder:SetDesiredAngle(-3.14 /2)
	RightHip:SetDesiredAngle(3.14 /2)
	LeftHip:SetDesiredAngle(-3.14 /2)
end

local lastTick = 0

function move(time)
	local amplitude = 1
	local frequency = 1
  	local deltaTime = time - lastTick
  	lastTick = time

	local climbFudge = 0
	local setAngles = false

  	if (jumpAnimTime > 0) then
  		jumpAnimTime = jumpAnimTime - deltaTime
  	end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif (pose == "Running") then
		playAnimation("walk", 0.1, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
--		print("Wha " .. pose)
		stopAllAnimations()
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end

	if (setAngles) then
		local desiredAngle = amplitude * math.sin(time * frequency)

		RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
		LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
		RightHip:SetDesiredAngle(-desiredAngle)
		LeftHip:SetDesiredAngle(-desiredAngle)
	end

	-- Tool Animation handling
	local tool = getTool()
	if tool and tool:FindFirstChild("Handle") then
	
		local animStringValueObject = getToolAnim(tool)

		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			-- message recieved, delete StringValue
			animStringValueObject.Parent = nil
			toolAnimTime = time + .3
		end

		if time > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end

		animateTool()		
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimInstance = nil
		toolAnimTime = 0
	end
end

-- connect events
Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)

-- setup emote chat hook
game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
	local emote = ""
	if msg == "/e dance" then
		emote = dances[math.random(1, #dances)]
	elseif (string.sub(msg, 1, 3) == "/e ") then
		emote = string.sub(msg, 4)
	elseif (string.sub(msg, 1, 7) == "/emote ") then
		emote = string.sub(msg, 8)
	end
	
	if (pose == "Standing" and emoteNames[emote] ~= nil) then
		playAnimation(emote, 0.1, Humanoid)
	end

end)


-- main program

-- initialize to idle
playAnimation("idle", 0.1, Humanoid)
pose = "Standing"

while Figure.Parent ~= nil do
	local _, time = wait(0.1)
	move(time)
end


]]},
[22]={class=[[LocalScript]],source=[[local runService = game:GetService("RunService")

local MOMENTUM_FACTOR = 0.006
local MIN_MOMENTUM = 0.13
local MAX_MOMENTUM = 0.13
local SPEED = 7

local character = script.Parent
local humanoid = character.Humanoid
local humanoidRootPart = character.HumanoidRootPart
local m6d = nil
local originalM6dC0 = nil

if humanoid.RigType == Enum.HumanoidRigType.R15 then
	local lowerTorso = character.LowerTorso
	m6d = lowerTorso.Root
else
	m6d = humanoidRootPart.RootJoint
end
originalM6dC0 = m6d.C0

runService.Heartbeat:Connect(function(dt)
	if not character:GetAttribute("qbfd8b3bf7ac864d9") and not character:GetAttribute("q9e5fe3c6a1262529") then
		local direction = humanoidRootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
		local momentum = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)*MOMENTUM_FACTOR
		momentum = Vector3.new(
			math.clamp(math.abs(momentum.X), MIN_MOMENTUM, MAX_MOMENTUM),
			0,
			math.clamp(math.abs(momentum.Z), MIN_MOMENTUM, MAX_MOMENTUM)
		)

		local x = direction.X*momentum.X
		local z = (direction.Z*momentum.Z) / 2

		local angles = nil
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			angles = {z, 0, -x}
		else
			angles = {-z, -x, 0}
		end

		m6d.C0 = m6d.C0:Lerp(originalM6dC0*CFrame.Angles(unpack(angles)), dt*SPEED)
	end
end)]]},
[23]={class=[[LocalScript]],source=[[
local player = game.Players.LocalPlayer
local Remote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Ragdoll")
local RagdollForce = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RagdollForce")
local OnDeath = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OnDeath")
local Char = player.Character or player.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

Remote.OnClientEvent:Connect(function(toggle)
	if Hum.Health > 0 then
		if toggle then
			Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
			Hum:ChangeState(Enum.HumanoidStateType.Physics)
			Hum.AutoRotate = false
		else
			Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
			Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
			Hum.AutoRotate = true
		end
		--Hum.AutoRotate = false

		--if duration then
		--task.delay(duration,function()				
		--	Hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
		--	Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		--	Hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false)
	 --       -- Hum.AutoRotate = true
		--	end)
		--	end
	end
end)

RagdollForce.OnClientEvent:Connect(function()
	warn("RAGDOLL FORCE")
	local Force = Instance.new("LinearVelocity",Root:FindFirstChild("ForceAttachment"))
	Force.Attachment0 = Root:FindFirstAncestor("ForceAttachment")
	Force.RelativeTo = Enum.ActuatorRelativeTo.World
	Force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Force.MaxForce = math.huge
	Force.VectorVelocity = Root.CFrame.LookVector * 5
	Force.Enabled = true
	game.Debris:AddItem(Force,0.1)	

end)

Hum.Died:Connect(function()
	OnDeath:FireServer(Char)	 
end)


]]},
[24]={class=[[LocalScript]],source=[[local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local torso = char:WaitForChild("Torso")
local Remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local TestAnimation = Remotes:WaitForChild("TestAnimation")
local ToggleResetting = Remotes:WaitForChild("ToggleResetting")
local WallBounce = Remotes:WaitForChild("WallBounce")
local Subtitles = Remotes:WaitForChild("Subtitles")
local Emote = Remotes:WaitForChild("Emote")
local uis = game:GetService("UserInputService")

local uis = game:GetService("UserInputService")

local defaultWalkspeed = hum.WalkSpeed

local StarterGui = game:GetService("StarterGui")
local ts = game:GetService("TweenService")
-- lets disable the modifications on Combat for now then, just to not conflict; so we just disable the main script in combat?,
-- i know, but when you do that, don't we lose a lot of stuff?
-- What does Main even do @-@
--nono but like look, we can disable and renable it with bool really easily, not even delete just enable since you can do that with localscripts
--no bc we just disable a scritp we can reanable easily, and the script did load beforeso it should be all fine i believe
-- lemme see
if not player.PlayerGui:FindFirstChild("verify") then
	print("not enabled")
	
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	local coreCall do
		local MAX_RETRIES = 25

		local StarterGui = game:GetService('StarterGui')
		local RunService = game:GetService('RunService')

		function coreCall(method, ...)
			local result = {}
			for retries = 1, MAX_RETRIES do
				result = {pcall(StarterGui[method], StarterGui, ...)}
				if result[1] then
					break
				end
				RunService.Stepped:Wait()
			end
			return unpack(result)
		end
	end
	assert(coreCall('SetCore', 'ResetButtonCallback', true))
else
	print("set false")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	local coreCall do
		local MAX_RETRIES = 25

		local StarterGui = game:GetService('StarterGui')
		local RunService = game:GetService('RunService')

		function coreCall(method, ...)
			local result = {}
			for retries = 1, MAX_RETRIES do
				result = {pcall(StarterGui[method], StarterGui, ...)}
				if result[1] then
					break
				end
				RunService.Stepped:Wait()
			end
			return unpack(result)
		end
	end
	assert(coreCall('SetCore', 'ResetButtonCallback', false))
end

local rs = game:GetService("ReplicatedStorage")
local Remotes = rs:WaitForChild("Remotes")
--local SelfRagdoll = Remotes:WaitForChild("SelfRagdoll")
--local RagdollPlayer = Remotes:WaitForChild("RagdollPlayer")

local subText = player.PlayerGui.Subtitles.TextLabel

local localStun = 0

char.ChildAdded:Connect(function(child)
	if child:IsA("BoolValue") and child.Name == "qbfd8b3bf7ac864d9" then
		hum.WalkSpeed = 0
		hum.AutoRotate = false
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	elseif child:IsA("BoolValue") and child.Name == "q811f2132e7542a42" then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end
end)

char.ChildRemoved:Connect(function()
	for _,v in char:GetChildren() do
		if v:IsA("BoolValue") and v.Name == "qbfd8b3bf7ac864d9" then
			return
		end
	end
	if char:GetAttribute("q9e5fe3c6a1262529") == false and not player.PlayerGui:FindFirstChild("verify") then
		hum.WalkSpeed = defaultWalkspeed
		hum.AutoRotate = true
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
		if char:GetAttribute("q9e5fe3c6a1262529") == false and not player.PlayerGui:FindFirstChild("verify") then
		hum.WalkSpeed = defaultWalkspeed
		hum.AutoRotate = true
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
end)

hum.StateChanged:Connect(function(state)
	if state == Enum.HumanoidStateType.Landed then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		wait(0.001)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end)

local function calculateClosestPartSide(target, dest)
	local targetPos = target.Position
	local destPos = dest.Position
	local destSize = dest.Size

	local positions = {
		Vector3.new(destPos.X + (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X - (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X, destPos.Y + (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y - (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y, destPos.Z + (destSize.Z / 2)),
		Vector3.new(destPos.X, destPos.Y, destPos.Z - (destSize.Z / 2))
	}

	local closestPos = positions[1]
	local smallestMagnitude = math.abs((positions[1] - targetPos).Magnitude)

	for _,pos in positions do
		local currentMagnitude = math.abs((pos - targetPos).Magnitude)
		if (currentMagnitude < smallestMagnitude) then
			closestPos = pos
			smallestMagnitude = currentMagnitude
		end
	end

	if closestPos == nil then
		warn("nil position")
	end

	return {closestPos, smallestMagnitude}
end
for i,v in pairs(game.Workspace:GetChildren()) do
	if v:FindFirstChild("IsMap") then
		local BoundableWalls = v:WaitForChild("BoundableWalls")
		for _,v in char:GetChildren() do
			if v:IsA("BasePart") then
				v.Touched:Connect(function(part)
					if part.Parent == BoundableWalls and not char:GetAttribute("q9e5fe3c6a1262529") and char:GetAttribute("qa44eaa7e1ad00eaa") and not char:GetAttribute("q709f65b2f3149155") then
						warn("touched")
						char:SetAttribute("q709f65b2f3149155", true)
						-- wall bounce fire server
						--WallBounce:FireServer(part)

						local root = char.HumanoidRootPart
						local savedPosition = root.Position

						local closestInfo = calculateClosestPartSide(root, part)

						local unit = (closestInfo[1] - part.Position).unit * -2.5
						local refUnit = (closestInfo[1] - part.Position).unit * 20
						local newPosition = CFrame.new(savedPosition) * unit
						local refPosition = CFrame.new(savedPosition) * refUnit

						local finalCframe = CFrame.new(newPosition.X, root.Position.Y, newPosition.Z)
						finalCframe = CFrame.lookAt(root.Position, refPosition)

						WallBounce:FireServer(part, finalCframe)
					end
				end)
			end
		end
	end
end

ToggleResetting.OnClientEvent:Connect(function(toggle)
	local coreCall do
		local MAX_RETRIES = 25

		local StarterGui = game:GetService('StarterGui')
		local RunService = game:GetService('RunService')

		function coreCall(method, ...)
			local result = {}
			for retries = 1, MAX_RETRIES do
				result = {pcall(StarterGui[method], StarterGui, ...)}
				if result[1] then
					break
				end
				RunService.Stepped:Wait()
			end
			return unpack(result)
		end
	end
	
	if toggle then
		assert(coreCall('SetCore', 'ResetButtonCallback', true))
	else
		assert(coreCall('SetCore', 'ResetButtonCallback', false))
	end
end)

Subtitles.OnClientEvent:Connect(function(text, dur)
	subText.TextTransparency = 1
	subText.TextStrokeTransparency = 1
	subText.Text = text
	
	local ti = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local ti2 = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local t1 = ts:Create(subText, ti, {TextTransparency = 0})
	local t2 = ts:Create(subText, ti, {TextStrokeTransparency = 0})
	t1:Play()
	t2:Play()
	t1.Completed:Wait()
	wait(dur)
	local t3 = ts:Create(subText, ti2, {TextTransparency = 1})
	local t4 = ts:Create(subText, ti2, {TextStrokeTransparency = 1})
	t3:Play()
	t4:Play()
end)

uis.InputBegan:Connect(function(input, gp)
	if gp then return end
	if char:FindFirstChild("qbfd8b3bf7ac864d9") then
		if char.stun:IsA("BoolValue") then
			return
		end
	end
	if char:FindFirstChild("q811f2132e7542a42") then
		if char.carrying:IsA("BoolValue") then
			return
		end
	end
	if char:GetAttribute("q9e5fe3c6a1262529") == true then
		return 
	end
	if input.KeyCode == Enum.KeyCode.G then
		Emote:FireServer("1")
	elseif input.KeyCode == Enum.KeyCode.H then
		Emote:FireServer("2")
	elseif input.KeyCode == Enum.KeyCode.J then
		Emote:FireServer("3")
	elseif input.KeyCode == Enum.KeyCode.K then
		Emote:FireServer("4")
	elseif input.KeyCode == Enum.KeyCode.L then
		Emote:FireServer("5")
	end
end)


--uis.InputBegan:Connect(function(input, gp)
--	if gp then return end
--	if input.KeyCode == Enum.KeyCode.T then
--		TestAnimation:FireServer()
--	end
--end)
]]},
},roots={1,22,23,24}}