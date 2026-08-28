print("Script by Really312")

-- Variables

local screen = script.Parent
local music = screen.Sound
local light = screen.SurfaceLight
local channel = screen.Channel
local img = screen.Decal
local volumeValue = music.VolumeValue
local On = false -- Boolean, it's false because the TV is off xd.
local TV = screen.Parent

local images = {"rbxassetid://25067669", "rbxassetid://1365494765", "rbxassetid://1047349259", 
	"rbxassetid://4211688935", "rbxassetid://6005978142", 
	"rbxassetid://884939526", "rbxassetid://1387747614", "rbxassetid://8682210138", 
	"rbxassetid://5332165856", "rbxassetid://5633073236", "rbxassetid://272503456"} -- Add or change images here. (insert ID image, not decal)
local songs = {"rbxassetid://702875426", "rbxassetid://1837889876", "rbxassetid://1846537079", 
	"rbxassetid://1838215270", "rbxassetid://1837739605", 
	"rbxassetid://1839822906", "rbxassetid://1843083050", "rbxassetid://1842062535", 
	"rbxassetid://9048653040", "rbxassetid://1841796709", "rbxassetid://1837870468"} -- Add or change songs here.

local MaxChannel = #songs -- This value depends on how many items exist on the "song" table

-- Channel Functions --

function ChannelDown()
	channel.Value = channel.Value - 1
end

TV.CButtonDown.ClickDetector.MouseClick:Connect(ChannelDown)

function ChannelUp()
	channel.Value = channel.Value + 1
end

TV.CButtonUp.ClickDetector.MouseClick:Connect(ChannelUp)


local function ChangeChannel()
	if channel.Value < 1 then -- If the VALUE is 0, the script won't work bc the value is nil on the tables.
		channel.Value = MaxChannel -- You can change the MaxChannel value if you like.
	elseif channel.Value > MaxChannel then
		channel.Value = 1
	else
		music.SoundId = songs[channel.Value]
		music:Play()
		img.Texture = images[channel.Value]
		
	end
end


channel.Changed:Connect(ChangeChannel)

-- Volume Functions --

function VolumeUp()
	volumeValue.Value = volumeValue.Value + 0.1
end

TV.VButtonUp.ClickDetector.MouseClick:Connect(VolumeUp)

function VolumeDown()
	volumeValue.Value = volumeValue.Value - 0.1
end

TV.VButtonDown.ClickDetector.MouseClick:Connect(VolumeDown)

function VolumeChanged()
	if volumeValue.Value < 0 then
		volumeValue.Value = 0
	elseif volumeValue.Value > 1.2 then
		volumeValue.Value = 1.2 -- I don't recommend any value higher than 1, it's annoying.
	else
		music.Volume = volumeValue.Value
	end
end

volumeValue.Changed:Connect(VolumeChanged)

-- Turn On/Off Function --

function ActionButton() -- idk how to call it.
	if On then -- Checks if On is true. It's not necessary add "On == true", just write the boolean and "then" after it.
		On = false
		light.Enabled = false
		music:Pause()
		img.Transparency = 1
		screen.BrickColor = BrickColor.Black()
		screen.Material = Enum.Material.Glass
	elseif not On then --Checks if On is false.
		On = true
		light.Enabled = true
		music:Play()
		img.Transparency = 0
		screen.BrickColor = BrickColor.White()
		screen.Material = Enum.Material.Neon
	end
end

TV["ButtonOn/Off"].ClickDetector.MouseClick:Connect(ActionButton)

--[[					-Credits-
		-Music-

	1: rbxassetid://702875426 \\ No signal

	2: rbxassetid://1837889876 \\ Cry
	
	3: rbxassetid://1846537079 \\ Cry For More (A)
	
	4: rbxassetid://1838215270 \\ Metal Monster

	5: rbxassetid://1837739605 \\ Metal Mars (a)
	
	6: rbxassetid://1839822906 \\ Guitar and Synths
	
	7: rbxassetid://1843083050 \\ Daydreamer - (No Synths)
	
	8: rbxassetid://1842062535 \\ Future Bass (a)
	
	9: rbxassetid://9048653040 \\ Blue In Blue
	
	10: rbxassetid://1841796709 \\ Solitude (b)
	
	11: rbxassetid://1837870468 \\ Ramp it Up - No Lead
	
	
		-Images-
		
	1: rbxassetid://25067669 \\ No Signal

	2: rbxassetid://1365494765 \\ Galaxy

	3: rbxassetid://1047349259 \\ Night Time City
	
	4: rbxassetid://4211688935 \\ skeleton
	
	5: rbxassetid://6005978142 \\ xenomorph
	
	6: rbxassetid://884939526 \\ urban
	
	7: rbxassetid://1387747614 \\ clouds
	
	8: rbxassetid://8682210138 \\ city
	
	9: rbxassetid://5332165856 \\ ocean
	
	10: rbxassetid://5633073236 \\ dark forest
	
	11: rbxassetid://272503456 \\ protocol symbol
	
--]]