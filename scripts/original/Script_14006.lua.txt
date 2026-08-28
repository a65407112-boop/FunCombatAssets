while task.wait() do
	script.Parent.CFrame = script.Parent.CFrame * CFrame.fromEulerAnglesXYZ(0,0,0.05)
end