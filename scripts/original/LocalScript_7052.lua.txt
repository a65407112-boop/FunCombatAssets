local chat = game:GetService("TextChatService")
local channel = chat:WaitForChild("TextChannels"):WaitForChild("RBXSystem")

--channel:DisplaySystemMessage('<font color="#EE4B2B">yea :3</font>')

local awakenEvent = game:GetService("ReplicatedStorage").RemoteEvents.awakenEvent
local chatEvent = game:GetService("ReplicatedStorage").RemoteEvents.chatEvent
local weatherEvent = game:GetService("ReplicatedStorage").RemoteEvents.weatherEvent -- done jst go teamtest

awakenEvent.OnClientEvent:Connect(function(player, message)
	channel:DisplaySystemMessage('<font color="#700320">' .. player.." Has Awakened" .. '</font>')
end)

chatEvent.OnClientEvent:Connect(function(message)
	channel:DisplaySystemMessage('<font color="#8E00B9">' .. message .. '</font>')
end)

weatherEvent.OnClientEvent:Connect(function(message)
	channel:DisplaySystemMessage('<font color="#5799FC">' .. "The Weather is changing to: " .. message .. '</font>')
end)