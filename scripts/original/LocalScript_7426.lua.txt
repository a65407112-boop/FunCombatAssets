--Ty roblox
repeat wait() until script.Parent == game.Players.LocalPlayer.PlayerGui
script.Parent = game.Players.LocalPlayer.PlayerScripts
--

local KeyframeAnimation = script.Animation.Value
local rig = script.Rig.Value
local origin = script.Origin.Value

local keyframeList
if KeyframeAnimation ~= nil then
	keyframeList = KeyframeAnimation:GetKeyframes()
end

local KFNumber = 1
local maxKFNumber
if keyframeList ~= nil then
	maxKFNumber = #keyframeList
end

local basePositions = {}
local lastPositions = {}
local desiredPositions = {}

--FUNCTIONS

local function getJointBetween(part0, part1)
	for _, obj in pairs(part1:GetChildren()) do
		if obj:IsA("Motor6D") and obj.Part0 == part0 then
			return obj
		end
	end
	for _, obj in pairs(part0:GetChildren()) do
		if obj:IsA("Motor6D") and obj.Part1 == part1 then
			return obj
		end
	end
end

function UpdatePositions()
	
	local targetKF = keyframeList[KFNumber]
	
	local function RecursivelyUpdatePositions(parentPose, poseObject)
		if parentPose then
			if rig then
				local FoundParent
				local FoundPoseObject
				for _,p in rig:GetDescendants() do
					if p.Parent:IsA("Accessory") == false and p:IsA("BasePart") then
						if p.Name == parentPose.Name then
							FoundParent = p
						end
						if p.Name == poseObject.Name then
							FoundPoseObject = p
						end
					end
				end
				
				--local FoundParent = rig:FindFirstChild(parentPose.Name, true)
				--local FoundPoseObject = rig:FindFirstChild(poseObject.Name, true)
				if FoundParent and FoundPoseObject then
					local joint = getJointBetween(FoundParent, FoundPoseObject)
					if joint then
					
						--A keyframe Joint was found, proceed with schedulation
						lastPositions[joint] = joint.Transform
						desiredPositions[joint] = poseObject.CFrame
						--
					
					end
				end
			end
		end
		
		for _, subPose in pairs(poseObject:GetSubPoses()) do
			RecursivelyUpdatePositions(poseObject, subPose)
		end
		
	end
	
	if targetKF then
		timeNeeded = targetKF.Time
		
		for _, poseObj in pairs(targetKF:GetPoses()) do
			RecursivelyUpdatePositions(nil, poseObj)
		end
	end
	--timeNeeded = targetKF.Time
end

function ResetJoints()
	for i, v in pairs(basePositions) do
		i.Transform = CFrame.new()
	end
end
--

--CODE RUN
local t = 0
timeNeeded = 0

UpdatePositions()

local AnimatingBind = game["Run Service"].Stepped:Connect(function(totalTime, step)
	
	t = t + (step * origin.Speed.Value)
	local alpha
	if timeNeeded == 0 then
		alpha = 1
	else
		alpha = math.min(1, t / math.max(.001,timeNeeded))
	end
	 
	
	for limb, position in pairs(desiredPositions) do
		limb.Transform = lastPositions[limb]:lerp(desiredPositions[limb], alpha)
		if alpha == 1 then
			lastPositions[limb] = desiredPositions[limb]
		end
	end
	
	if alpha == 1 then
		KFNumber = KFNumber + 1
		if KFNumber > maxKFNumber then
			if KeyframeAnimation.Loop then
				--ResetJoints()
				KFNumber = 1
			else
				ResetJoints()
				script:Destroy()
			end
		end
		
		UpdatePositions()
		t = 0
	end
	
end)
--

--RemoveEvent
origin.StopAnimation.OnClientEvent:Connect(function()
	if origin then
		origin.StopAnimationControl.ConfirmDestruction:FireServer()
	end
	AnimatingBind:Disconnect()
	ResetJoints()
	script:Destroy()
end)
--