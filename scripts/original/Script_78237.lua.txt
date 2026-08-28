game.Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(message)
		if table.find({"spawn","d","sd","/s","/sd","/spawn"}, message:split(" ")[1]) and game.Workspace.Configuration.AllowDummys.Value == true then
			local Rig = game:GetService("ReplicatedStorage").Rig:Clone()
			Rig.Parent = workspace
			Rig:MoveTo(p.Character.PrimaryPart.Position + Vector3.new(0,0,-5))
			pcall(function()
				if tonumber(message:split(" ")[2]:lower()) then
					local UserId = tonumber(message:split(" ")[2]:lower())
					local Humanoid = game:GetService("Players"):GetHumanoidDescriptionFromUserId(tonumber(message:split(" ")[2]:lower()))
					Rig.Humanoid:ApplyDescriptionReset(Humanoid)
					Rig.Head.stats.Frame.TextLabel.Text = game:GetService("UserService"):GetUserInfosByUserIdsAsync({UserId})[1].Username
				end
			end)
		end
	end)
end)