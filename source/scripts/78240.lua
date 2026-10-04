local rs = game.ReplicatedStorage

local animatorFolder
local maps = rs:WaitForChild("Maps")
local res = rs:WaitForChild("RemoteEvents")
local chatEvent = res:WaitForChild("chatEvent")
local chat = game:GetService("TextChatService")
local channel = chat:WaitForChild("TextChannels"):WaitForChild("RBXSystem")
local rs = game:GetService("ReplicatedStorage")
local CombatFunctions = require(rs:WaitForChild("CombatFunctions"))

local numMapsVoting = 3
local intermissionTime = 5
local voteTime = 15
local currentMapName = ""
local currentMap

local plrVotes = {}

local players = {}


function addVote(plr:Player, mapName:string)
	plrVotes[plr] = mapName
	res:WaitForChild("Voted"):FireAllClients(plrVotes)
end

function removePlayerVote(plr:Player)
	plrVotes[plr] = nil
	res:WaitForChild("Voted"):FireAllClients(plrVotes)
end

function loadMap(mapName:string)
	
	local newMap = maps[mapName]:Clone()
	newMap.Parent = workspace
	currentMap = mapName
	
	
	local spawns = newMap:WaitForChild("Spawns"):GetChildren()
	
	for i, plr in pairs(game.Players:GetPlayers()) do
		if plr.Character then
			plr.Character.HumanoidRootPart.CFrame = (spawns[i] and spawns[i].CFrame or spawns[i-#spawns]) + Vector3.new(0, 10, 0)
		end
	end
	
	for _, plr in pairs(game.Players:GetPlayers()) do
		-- current_player.leaderstats.Killstreak.Value = killstreak 
		local killstreak = plr.leaderstats.Killstreak.Value
		wait(0.1)
		plr:LoadCharacter()
		wait(0.5)
		plr.leaderstats.Killstreak.Value = killstreak

		if(killstreak >= 5) then
			CombatFunctions:awaken(plr.Character) -- alrighty
		end
	end
	
	return newMap
end

function removeMap(map:Instance)
	
	local workspace = game.Workspace
	local animatorFolder = workspace:FindFirstChild("AnimatorFolder")
	if(animatorFolder) then
		animatorFolder:Destroy()
	end
	
	
	for i,v in pairs(workspace:GetChildren()) do
			if v:FindFirstChild("IsMap") then
				v:Destroy() -- now working
			end
		end
end

function handleRound()
	for i = 0, 100 do -- 0, 100
		task.wait(12) -- 12
		players = game:GetService("Players"):GetPlayers()
		if #players < 2 then 
			break
		end
	end
--[[	local plrsAlive = {}
	for _, plr in pairs(game.Players:GetPlayers()) do
		
		if plr.Character and plr.Character.Humanoid.Health > 0 then
			table.insert(plrsAlive, plr)
			
			plr.Character.Humanoid.Died:Connect(function()
				table.remove(plrsAlive, table.find(plrsAlive, plr))
			end)
		end
	end
	
	for i = 1, 20 do
		task.wait(1)
		if #plrsAlive == 0 then
			break
		end
	end]]
	
end


res:WaitForChild("Voted").OnServerEvent:Connect(addVote)

game.Players.PlayerRemoving:Connect(removePlayerVote)

local firstTime = true

while true do
	
	players = game:GetService("Players"):GetPlayers()
	local newMap
	
	if(#players >= 2) then
		task.wait(intermissionTime)

		local mapsToVote = maps:GetChildren()

		while #mapsToVote > numMapsVoting do
			table.remove(mapsToVote, math.random(1, #mapsToVote))
		end

		plrVotes = {}

		res:WaitForChild("VotingBegun"):FireAllClients(mapsToVote)

		task.wait(voteTime)

		local highestVotedFor = nil

		local votes = {}
		for i, map in pairs(mapsToVote) do
			votes[map.Name] = 0

			if i == 1 then
				highestVotedFor = map.Name
			end
		end

		for plr, vote in pairs(plrVotes) do

			if votes[vote] then
				votes[vote] += 1

				if votes[highestVotedFor] < votes[vote] then
					highestVotedFor = vote
				end
			end
		end
		
		if(firstTime) then
			firstTime = false
			for _, v in ipairs(game:GetService("Workspace"):GetChildren()) do
				if(v:FindFirstChild("IsMap")) then
					newMap = v
					currentMap = v.Name
					break
				end
			end
		end
		
		if(currentMap ~= highestVotedFor::string) then
			chatEvent:FireAllClients("Switching to Map: ".. highestVotedFor::string .." In 5 Seconds")
			task.wait(5)
			removeMap(currentMap)
			newMap = loadMap(highestVotedFor)
		end

		res:WaitForChild("VotingEnded"):FireAllClients()

		handleRound()
	else
		task.wait(5)
	end
	
end