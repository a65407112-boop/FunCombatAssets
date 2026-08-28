local ts = game:GetService("TweenService")
local Toggle = script.Parent.Parent:WaitForChild("Toggle")
local Press = script.Parent:WaitForChild("Press")

script.Parent.MouseButton1Click:Connect(function()
	Toggle.Value = not Toggle.Value
	Press:Play()
	if (Toggle.Value) then
		script.Parent.TextLabel.Text = "Hitboxes: On"
	else
		script.Parent.TextLabel.Text = "Hitboxes: Off"
	end
end)

local vertTi = TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local horTi = TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local vertT = ts:Create(script.Parent, vertTi, {Position = UDim2.new(1,-150,0.75,0)})
local horT = ts:Create(script.Parent, horTi, {Rotation = 4})
vertT:Play()
wait(0.6)
horT:Play()