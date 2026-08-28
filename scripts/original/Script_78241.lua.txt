
local currentWeatherState = ""
local currentMap = ""

local rs = game.ReplicatedStorage
local res = rs:WaitForChild("RemoteEvents")
local weatherEvent = res:WaitForChild("weatherEvent")

local function clearWeather()
	for i,v in pairs(game.Lighting:GetChildren()) do
		v:Destroy()
	end
	
	for i,v in pairs(game.Workspace:GetChildren()) do
		if v.Name == "Clouds" then
			v:Destroy()
		end
	end
	
	
	if(currentWeatherState == "Rainy") then
		for _,current_player in game.Players:GetPlayers() do
			current_player.PlayerGui.Rain:WaitForChild("IsRaining").Value = false
		end
	end

end


local function Sunny()
	
	if(currentWeatherState == "Sunny") then
		return
	end
	
	
	clearWeather()
	local sunny = game:GetService("ReplicatedStorage").Weather.NormalLightning
	for i,v in pairs(sunny:GetChildren()) do
		v:Clone().Parent = game:GetService("Lighting")
	end
	
	currentWeatherState = "Sunny"
end

local function Cloudy()
	if(currentWeatherState == "Cloudy" or currentWeatherState == "Rainy") then
		return
	end
	
	
	clearWeather()
	local rainfolder = game:GetService("ReplicatedStorage").Weather.Rainy
	for i,v in pairs(rainfolder:GetChildren()) do
		if not v:IsA("Model") or v:IsA("LocalScript") then
			v:Clone().Parent = game:GetService("Lighting")
		end
		if v:IsA("Model") then
			v:Clone().Parent = game.Workspace
		end
	end

	currentWeatherState = "Cloudy"
end

local function Rain()	
	Cloudy()
	
	
	currentWeatherState = "Rainy"
	
	for _,current_player in game.Players:GetPlayers() do
		current_player.PlayerGui.Rain:WaitForChild("IsRaining").Value = true
	end
	
--[[	local randomThunder = (math.random() * 100)
	if(randomThunder < 20) then
		-- Activate thunder on all players; otherwise, no
		currentWeatherState = "Thunderstorm"
	end]]
end

local function PurpleFog()
	if(currentWeatherState == "PurpleFog") then
		return
	end
	
	
	clearWeather()
	local Lightning = game:GetService("ReplicatedStorage").Weather["Purple/PurpleFog"]
	for i,v in pairs(Lightning:GetChildren()) do
		v:Clone().Parent = game:GetService("Lighting")
	end
	
	currentWeatherState = "PurpleFog"
end

function changeWeather()
	
	math.randomseed(os.time())
	local rand = (math.random() * 100)
	
	if(currentMap == "OriginalMap") then
		-- PurpleFog 7%
		-- Cloudy: 33%
		-- Rainy: 20%
		-- Sunny: 40%
		
		if(rand <= 7) then
			PurpleFog()
		elseif(rand <= 40) then
			Cloudy()
		elseif(rand <= 60) then
			Rain()
		end
		
		if(rand <= 60) then
			return
		end
	else
		-- Rainy: 30%
		-- Cloudy: 30%
		-- Sunny: 40%
		if(rand <= 30) then
			Rain()
		elseif(rand <= 60) then
			Cloudy()
		end
		
		if(rand <= 60) then
			return
		end
	end
	
	-- In case no special rain;
	Sunny()	
end

function getMap()
	for i,v in pairs(game.Workspace:GetChildren()) do
		if v:FindFirstChild("IsMap") then
			currentMap =  v.Name
		end
	end
end
	
local function activateForPlayer(addedPlayer)
	if(currentWeatherState == "Rainy") then
		addedPlayer.PlayerGui.Rain:WaitForChild("IsRaining").Value = true
	end
end
	
	

game.Players.PlayerAdded:Connect(function(added)
	activateForPlayer(added)
	added.CharacterAdded:Connect(function(character)
		activateForPlayer(added)
	end)
end)



while true do	
	if(#game:GetService("Players"):GetPlayers() <= 1) then
		task.wait(20)
		continue
	end
	
	if(currentWeatherState == "") then --This script is on server, so if its EMPTY it means the server just booted;
		Sunny()
	else		
		changeWeather()
	end
	
	weatherEvent:FireAllClients(currentWeatherState)
	--warn(currentWeatherState)
	--task.wait(20)
	task.wait(720) -- Each 5 minutes, it checks to see if its gonna change!
end