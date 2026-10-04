
game:GetService('NetworkClient').ChildRemoved:Connect(function(child)
	if child:IsA('ClientReplicator') then
		while true do
			wait()
			script.Parent.Enabled = true
		end
	end
end)

script.Parent.Enabled = false