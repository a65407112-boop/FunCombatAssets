local ts = game:GetService("TweenService")
local ti = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local display = script.Parent.Parent.display

local rs = game:GetService("ReplicatedStorage")
local Remotes = rs:WaitForChild("Remotes")
local Emote = Remotes:WaitForChild("Emote")
local g

local offPos = UDim2.new(0.5,0,1.3,0)
local onPos = UDim2.new(0.5,0,0.6,0)
local onSFX = script:WaitForChild("onSFX")
local offSFX = script:WaitForChild("offSFX")

local v = false
local debounce = false

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()

script.Parent.ImageButton.Activated:Connect(function()
	if debounce then return end
	
	debounce = true
	if not v then
		local t = ts:Create(display, ti, {Position = onPos}):Play()
		onSFX:Play()
	else
		local t = ts:Create(display, ti, {Position = offPos}):Play()
		offSFX:Play()
	end
	v = not v
	wait(1)
	debounce = false
end)

for _,v in script.Parent.Parent.display:GetDescendants() do
	if v:IsA("TextButton") then
		v.Activated:Connect(function()
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
			Emote:FireServer(v.Name)
		end)
	end
end

local vertTi = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local horTi = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local vertT = ts:Create(script.Parent, vertTi, {Position = UDim2.new(0,30,0,10)})
local horT = ts:Create(script.Parent, horTi, {Rotation = -2})

vertT:Play()
wait(0.4)
horT:Play()