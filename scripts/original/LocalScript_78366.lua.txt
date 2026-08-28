script.Parent.MouseButton1Click:Connect(function()
	if script.Parent.Parent.Frame.Visible == false then
		script.Parent.Parent.Frame.Visible = true
	else
		script.Parent.Parent.Frame.Visible = false
	end
end)