local rs = game:GetService("ReplicatedStorage")
local ts = game:GetService('TweenService')
local Remotes = rs:WaitForChild("Remotes")
local AwakenScreen = Remotes:WaitForChild("AwakenScreen")

local ti = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ti2 = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ti2 = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

AwakenScreen.OnClientEvent:Connect(function()
	local light = script.ColorCorrection:Clone()
	light.Parent = game.Lighting
	
	game.Debris:AddItem(light, 0.5)
	
	task.spawn(function()
		for _,v in script.Parent:GetDescendants() do
			if v:IsA("ImageLabel") then
				v.Visible = true
				v.ImageTransparency = 0
				local y = ts:Create(v, ti2, {ImageTransparency = 1}):Play()
			end
		end
		wait(0.5)
		for _,v in script.Parent:GetDescendants() do
			if v:IsA("ImageLabel") then
				v.Visible = false
			end
		end
	end)
	
	local t = ts:Create(light, ti, {Brightness = 0.5}):Play()
	local t2 = ts:Create(light, ti, {Contrast = 1}):Play()
	local t3 = ts:Create(light, ti, {Saturation = 1}):Play()
	local t4 = ts:Create(light, ti, {TintColor = Color3.fromRGB(255,20,29)})
	t4:Play()
	t4.Completed:Wait()
	wait(.7)
	local t5 = ts:Create(light, ti2, {Brightness = 0}):Play()
	local t6 = ts:Create(light, ti2, {Contrast = 0}):Play()
	local t7 = ts:Create(light, ti2, {Saturation = 0}):Play()
	local t8 = ts:Create(light, ti2, {TintColor = Color3.fromRGB(255,255,255)})
	t8:Play()
	
end)