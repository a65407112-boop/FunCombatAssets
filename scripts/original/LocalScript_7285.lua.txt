local button = script.Parent
local player = game.Players.LocalPlayer
local targetGui = player:WaitForChild("PlayerGui"):WaitForChild("weapon")

button.MouseButton1Click:Connect(function()
	targetGui.Enabled = not targetGui.Enabled
end)