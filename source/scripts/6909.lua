local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")
local lp = game.Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local bar = script.Parent.container.bar
local ti = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ti2 = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ti3 = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local toggle = false

local FasterLabel = script.Parent.Parent.TextLabel
local rs = game:GetService("ReplicatedStorage")
local Remotes = rs:WaitForChild("Remotes")
local ChangeFunSpeed = Remotes:WaitForChild("ChangeFunSpeed")
local ShowPrompt = Remotes:WaitForChild("ShowPrompt")
local mobileButtons = lp.PlayerGui:WaitForChild("mobileButtons")
local RButton = mobileButtons:WaitForChild("R")

local LabelX = 30
local LabelY = 0
local LabelX2 = -0.51
local LabelY2 = -0.94

local prevMeter = 0
local newMeter

local funState = 1

local cam = game.Workspace.CurrentCamera

local Heartbeat = script:WaitForChild("Heartbeat")

if uis.TouchEnabled and not uis.KeyboardEnabled and not uis.MouseEnabled then
	warn("IS MOBILE")
	lp.PlayerGui.Shiftlock.Enabled = true
end

char:GetAttributeChangedSignal("funMeter"):Connect(function()
	newMeter = char:GetAttribute("funMeter")
	local t = ts:Create(bar, ti, {Size = UDim2.new(1,0,newMeter,0)})
	t:Play()
	--warn("updated fun: "..newMeter)
	--print(funState)
	
	if (char:GetAttribute("doing")) then
		if newMeter >= 1 and math.round(prevMeter * 100) == 98 then
			--warn("RELEASE")
			script.Parent.Parent.TextLabel.Visible = true
			toggle = true
			FasterLabel.Text = "R - RELEASE"
			local t = ts:Create(FasterLabel, ti2, {TextTransparency = 0})
			local t2 = ts:Create(FasterLabel, ti2, {TextStrokeTransparency = 0})
			local t3 = ts:Create(FasterLabel.ImageLabel, ti2, {ImageTransparency = 0.6})
			t:Play()
			t2:Play()
			t3:Play()
			funState += 1

		elseif newMeter >= 0.6 and math.round(prevMeter * 100) == 60 then
			--warn("2")
			script.Parent.Parent.TextLabel.Visible = true
			toggle = true
			FasterLabel.Text = "R - Faster"
			local t = ts:Create(FasterLabel, ti2, {TextTransparency = 0})
			local t2 = ts:Create(FasterLabel, ti2, {TextStrokeTransparency = 0})
			local t3 = ts:Create(FasterLabel.ImageLabel, ti2, {ImageTransparency = 0.6})
			t:Play()
			t2:Play()
			t3:Play()

			funState += 1
		elseif newMeter >= 0.26 and math.round(prevMeter * 100) == 26 then
			--warn("1")
			script.Parent.Parent.TextLabel.Visible = true
			toggle = true
			FasterLabel.Text = "R - Faster"
			local t = ts:Create(FasterLabel, ti2, {TextTransparency = 0})
			local t2 = ts:Create(FasterLabel, ti2, {TextStrokeTransparency = 0})
			local t3 = ts:Create(FasterLabel.ImageLabel, ti2, {ImageTransparency = 0.6})
			t:Play()
			t2:Play()
			t3:Play()

			funState += 1
		end
	else
		toggle = false
		FasterLabel.Text = ""
		local t3 = ts:Create(FasterLabel.ImageLabel, ti2, {ImageTransparency = 1})
	end
	
	if(funState >= 4) then
		funState = 4
	end

	
	prevMeter = newMeter
end)

local function theFunny(whiteScreen)
	local t = ts:Create(FasterLabel, ti2, {TextTransparency = 1})
	local t2 = ts:Create(FasterLabel, ti2, {TextStrokeTransparency = 1})
	local t3 = ts:Create(FasterLabel.ImageLabel, ti2, {ImageTransparency = 1})
	cam.FieldOfView = cam.FieldOfView + 20
	local t4 = ts:Create(cam, ti2, {FieldOfView = cam.FieldOfView - 20})
	t:Play()
	t2:Play()
	t3:Play()
	t4:Play()
	toggle = false
	
	Heartbeat:Play()
	
	task.spawn(function()
		t.Completed:Wait()
		script.Parent.Parent.TextLabel.Visible = false
	end)
	
	if whiteScreen then
		script.Parent.Parent.white.Visible = true
		script.Parent.Parent.white.ImageTransparency = 0
		local t5 = ts:Create(script.Parent.Parent.white, ti3, {ImageTransparency = 1})
		t5:play()

		for _,v in script.Parent.Parent.white:GetDescendants() do
			v.ImageTransparency = 0
			local t4 = ts:Create(v, ti3, {ImageTransparency = 1})
			t4:play()
		end
		
		t5.Completed:Wait()
		script.Parent.Parent.white.Visible = false
	end
end

uis.InputBegan:Connect(function(input, gp)
	if gp then return end
	
	--print(toggle)
	if input.KeyCode == Enum.KeyCode.R and toggle == true then
		
		if newMeter >= 1 then
			theFunny(true)
			task.spawn(function()
				wait(3)
				theFunny(true)
			end)
		else
			theFunny()
		end
		
		ChangeFunSpeed:FireServer(funState)	
		
		if funState == 4 then
			funState = 1
		end
	end
end)

RButton.Activated:Connect(function(input, clickCount)
	if toggle == true then
		if newMeter >= 1 then
			theFunny(true)
			task.spawn(function()
				wait(3)
				theFunny(true)
			end)
		else
			theFunny()
		end

		ChangeFunSpeed:FireServer(funState)	

		if funState == 4 then
			funState = 1
		end
	end
end)

ShowPrompt.OnClientEvent:Connect(function(prompt, toggle)
	if typeof(prompt) == "table" then
		for _,v in prompt do
			v.Enabled = toggle
		end
	else
		prompt.Enabled = toggle
	end
end)

char:GetAttributeChangedSignal("doing"):Connect(function()
	if char:GetAttribute("doing") == false then
		toggle = false
	end
end)

local vertTi = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local horTi = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local vertT = ts:Create(script.Parent, vertTi, {Position = UDim2.new(0,30,0.55,0)})
local horT = ts:Create(script.Parent, horTi, {Rotation = -3})
vertT:Play()
wait(0.6)
horT:Play()

while true do
	local randX = math.random(-10, 10)
	local randY = math.random(-10, 10)
	
	local randX2 = math.random(-0.1, 0.1)
	local randY2 = math.random(-0.1, 0.1)
	
	FasterLabel.Position = UDim2.new(0, LabelX + randX, 0.85, LabelY + randY)
	FasterLabel.ImageLabel.Position = UDim2.new(LabelX2 + randX2, 0, LabelY2 + randY2, 0)
	
	wait(0.05)
end

