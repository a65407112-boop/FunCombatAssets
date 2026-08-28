script.Parent.Enabled = true

local rs = game.ReplicatedStorage

local res = rs:WaitForChild("RemoteEvents")

local frame = script.Parent:WaitForChild("MapVoteFrame"); frame.Visible = false
local templateFrame = script:WaitForChild("MapFrame")


res:WaitForChild("VotingBegun").OnClientEvent:Connect(function(mapsToVote)
	
	for _, child in pairs(frame:WaitForChild("MapsContainer"):GetChildren()) do
		if child.ClassName == templateFrame.ClassName then
			child:Destroy()
		end
	end
	
	local mapFrames = {}
	
	for _, map in pairs(mapsToVote) do
		
		local newMapFrame = templateFrame:Clone()
		newMapFrame.Name = map.Name
		newMapFrame.MapName.Text = map.Name
		newMapFrame.NumVotes.Text = "Votes: 0"
		
		newMapFrame.VoteButton.MouseButton1Click:Connect(function()
			res:WaitForChild("Voted"):FireServer(map.Name)
		end)
		
		table.insert(mapFrames, newMapFrame)
	end
	
	table.sort(mapFrames, function(a, b)
		return a.Name < b.Name
	end)
	
	for _, mapFrame in pairs(mapFrames) do
		mapFrame.Parent = frame.MapsContainer
	end
	
	frame.Visible = true
end)


res:WaitForChild("VotingEnded").OnClientEvent:Connect(function()
	
	frame.Visible = false
end)


res:WaitForChild("Voted").OnClientEvent:Connect(function(plrVotes)
	
	if frame.Visible == true then
		
		local votes = {}
		
		for plr, vote in pairs(plrVotes) do
			
			if not votes[vote] then
				votes[vote] = 1
			else
				votes[vote] += 1
			end
		end
		
		for _, mapFrame in pairs(frame.MapsContainer:GetChildren()) do
			if mapFrame.ClassName == templateFrame.ClassName then
				mapFrame.NumVotes.Text = "Votes: " .. (votes[mapFrame.Name] or 0)
			end
		end
	end
end)