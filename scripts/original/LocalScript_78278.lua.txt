local admingui = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent.Parent

script.Parent.MouseButton1Click:Connect(function()
	if admingui.Frame.ProfileFrame.Visible == false then
		admingui.Frame.ProfileFrame.Visible = true
		admingui.Frame.CommandFrame.Visible = false
	end
end)