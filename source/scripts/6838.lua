local player = game.Players.LocalPlayer
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
	if child:IsA("BoolValue") and child.Name == "stun" then
		hum.WalkSpeed = 0
		hum.AutoRotate = false
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	elseif child:IsA("BoolValue") and child.Name == "carrying" then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end
end)

char.ChildRemoved:Connect(function()
	for _,v in char:GetChildren() do
		if v:IsA("BoolValue") and v.Name == "stun" then
			return
		end
	end
	if char:GetAttribute("downed") == false and not player.PlayerGui:FindFirstChild("verify") then
		hum.WalkSpeed = defaultWalkspeed
		hum.AutoRotate = true
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
		if char:GetAttribute("downed") == false and not player.PlayerGui:FindFirstChild("verify") then
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
					if part.Parent == BoundableWalls and not char:GetAttribute("downed") and char:GetAttribute("ragdolled") and not char:GetAttribute("wallBounce") then
						warn("touched")
						char:SetAttribute("wallBounce", true)
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
	if char:FindFirstChild("stun") then
		if char.stun:IsA("BoolValue") then
			return
		end
	end
	if char:FindFirstChild("carrying") then
		if char.carrying:IsA("BoolValue") then
			return
		end
	end
	if char:GetAttribute("downed") == true then
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
