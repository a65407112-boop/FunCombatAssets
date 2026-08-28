local MoveData = {
	["SWING_1"] = {
			-- GENERAL SETTINGS
			["offset"] = CFrame.new(0,0,-2),
			["size"] = Vector3.new(3,5,3),
			["damage"] = 20,
			["stun"] = 0.7,
			["vfx"] = "Default",
		
			-- FRAME DATA
			["startup"] = 18,
			["active"] = 10,
			["kb_force"] = 0,
			["kb_speed"] = 0,
			["kb_duration"] = 0,
			["stun_anim"] = "reaction_1",
			["fill_color"] = Color3.fromRGB(0,0,0),
			["outline_color"] = Color3.fromRGB(255,255,255)
			-- PROPERTIES		
	},
	["SWING_2"] = {
		-- GENERAL SETTINGS
		["offset"] = CFrame.new(0,0,-2),
		["size"] = Vector3.new(3,5,3),
		["damage"] = 20,
		["stun"] = 0.7,
		["vfx"] = "Default",
		["stun_anim"] = "reaction_2",

		-- FRAME DATA
		["startup"] = 18,
		["active"] = 10,
		["kb_force"] = 0,
		["kb_speed"] = 0,
		["kb_duration"] = 0,
		["fill_color"] = Color3.fromRGB(0,0,0),
		["outline_color"] = Color3.fromRGB(255,255,255)
		-- PROPERTIES		
	},
	["BIG_SWING"] = {
		-- GENERAL SETTINGS
		["offset"] = CFrame.new(0,0,-2),
		["size"] = Vector3.new(4,6,4),
		["damage"] = 40,
		["vfx"] = "Heavy",
		["stun_anim"] = "reaction_3",
		-- FRAME DATA
		["startup"] = 60,
		["active"] = 15,
		["ragdoll"] = 1.5,
		["stun"] = 1.5,
		["kb_force"] = 80000,
		["kb_speed"] = 50,
		["kb_duration"] = 0.4,
		["fill_color"] = Color3.fromRGB(255, 88, 130),
		["outline_color"] = Color3.fromRGB(0, 0, 0)
		-- PROPERTIES		
	},
	["GRIP_HIT"] = {
		-- GENERAL SETTINGS
		["damage"] = 10,
		["stun"] = 1,
		["vfx"] = "Heavy",
		-- FRAME DATA
		["kb_force"] = 0,
		["kb_speed"] = 0,
		["kb_duration"] = 0,
		["fill_color"] = Color3.fromRGB(255, 88, 130),
		["outline_color"] = Color3.fromRGB(0, 0, 0)
		-- PROPERTIES		
	},
	["BACK_START"] = {
		-- GENERAL SETTINGS
		["offset"] = CFrame.new(0,0,-2),
		["size"] = Vector3.new(3,5,3),
		["damage"] = 20,
		["stun"] = 0.7,
		["vfx"] = "Default",

		-- FRAME DATA
		["startup"] = 18,
		["active"] = 10,
		["kb_force"] = 0,
		["kb_speed"] = 0,
		["kb_duration"] = 0,
		["fill_color"] = Color3.fromRGB(0,0,0),
		["outline_color"] = Color3.fromRGB(255,255,255)
		-- PROPERTIES		
	},
	["BACK_BREAK"] = {
		-- GENERAL SETTINGS
		["damage"] = 10,
		["stun"] = 1,
		["vfx"] = "BackBreak",
		-- FRAME DATA
		["kb_force"] = 0,
		["kb_speed"] = 0,
		["kb_duration"] = 0,
		["fill_color"] = Color3.fromRGB(249, 255, 247),
		["outline_color"] = Color3.fromRGB(0, 0, 0)
		-- PROPERTIES		
	},
	["GRIP_FINISHER"] = {
		-- GENERAL SETTINGS
		["damage"] = 50,
		["stun"] = 3,
		["ragdoll"] = 3,
		["vfx"] = "Heavy",
		["kill"] = true,
		-- FRAME DATA
		["kb_force"] = 0,
		["kb_speed"] = 0,
		["kb_duration"] = 0,
		["fill_color"] = Color3.fromRGB(255, 88, 130),
		["outline_color"] = Color3.fromRGB(0, 0, 0)
		-- PROPERTIES		
	}
}

MoveData.__index = MoveData

function MoveData.get_data(move_name)
	return MoveData[move_name]
end


return MoveData
