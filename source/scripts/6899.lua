local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")
local lp = game.Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

local rs = game:GetService("ReplicatedStorage")
local Remotes = rs:WaitForChild("Remotes")
local GetUp = Remotes:WaitForChild("GetUp")

local ti = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
local ti2 = TweenInfo.new(0.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)

local bar = script.Parent.Frame.bar

local canGetUp = false
local getUpCount = 0

local mobileButtons = lp.PlayerGui:WaitForChild("mobileButtons")
local getUpButton = mobileButtons:WaitForChild("GetUp")

local function updateBar()
	local t = ts:Create(bar, ti2, {Size = UDim2.new(getUpCount, 0, 1, 0)})
	t:Play()
end

local function retractBar()
	canGetUp = false
	local t = ts:Create(script.Parent, ti, {Position = UDim2.new(0.5,0,1,50)})
	t:Play()
end

hum.HealthChanged:Connect(function(newHealth)
	if char:GetAttribute("downed") and char:GetAttribute("canGetUp") and newHealth >= hum.MaxHealth / 2 then
		canGetUp = true
		local t = ts:Create(script.Parent, ti, {Position = UDim2.new(0.5,0,1,-50)})
		t:Play()
	end
end)

char:GetAttributeChangedSignal("canGetUp"):Connect(function()
	if char:GetAttribute("canGetUp") == true then
		--warn("TRUE")
		if char:GetAttribute("downed") and char:GetAttribute("canGetUp") and hum.Health >= hum.MaxHealth / 2 then
			canGetUp = true
			local t = ts:Create(script.Parent, ti, {Position = UDim2.new(0.5,0,1,-50)})
			t:Play()
		end
	else
		retractBar()
	end
end)

uis.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.G and canGetUp then
		getUpCount += 0.05
		updateBar()
		if getUpCount >= 1 then
			getUpCount = 0
			updateBar()
			retractBar()
			
			GetUp:FireServer()
		end
	end
end)

getUpButton.Activated:Connect(function(input, clickCount)
	if canGetUp then
		getUpCount += 0.05
		updateBar()
		if getUpCount >= 1 then
			getUpCount = 0
			updateBar()
			retractBar()

			GetUp:FireServer()
		end
	end
end)

