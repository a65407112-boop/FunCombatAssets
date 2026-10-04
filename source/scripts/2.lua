local list = {
	1845341094,
	9046863253,
	9046864509,
	9043887091,
	1847506405,
	1837871067,
	1843468325,
	1845490105
}

local sound = script:WaitForChild("currentSound")
sound.SoundId = "rbxassetid://"..list[math.random(1,#list)]
sound:Play()

while true do
	sound.Ended:Wait()
	wait(3)
	sound.SoundId = "rbxassetid://"..list[math.random(1,#list)]
	sound:Play()
end