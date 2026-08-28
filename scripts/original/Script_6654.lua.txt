local TeleportPart1 = script.Parent.TeleportPart1
local TeleportPart2 = script.Parent.TeleportPart2

TeleportPart1.Touched:Connect(function(hit)
	local w = hit.Parent:FindFirstChild("HumanoidRootPart")
	if w then
		w.CFrame = TeleportPart2.CFrame + Vector3.new(0, 5, 0)
		TeleportPart2.CanTouch = false
		wait(1)
		TeleportPart2.CanTouch = true
	end
end)

TeleportPart2.Touched:Connect(function(hit)
	local w = hit.Parent:FindFirstChild("HumanoidRootPart")
	if w then
		w.CFrame = TeleportPart1.CFrame + Vector3.new(0, 5, 0)
		TeleportPart1.CanTouch = false
		wait(1)
		TeleportPart1.CanTouch = true
	end
end)