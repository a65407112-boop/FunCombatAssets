local admingui = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent

script.Parent.MouseButton1Click:Connect(function()
	if admingui.Frame.CommandFrame.Visible == false then
		admingui.Frame.ProfileFrame.Visible = false
		admingui.Frame.CommandFrame.Visible = true
	end
end)