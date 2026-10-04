local Remote = game.ReplicatedStorage.RemoteEvents.UIRemote

script.Parent.MouseButton1Click:Connect(function()
	Remote:FireServer(script.Parent.Parent.Text, "Kick")
end)