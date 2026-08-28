local Core = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local function base64Decode(value)
	local hasMethod, method = pcall(function() return HttpService.Base64Decode end)
	if hasMethod and method then
		local ok, decoded = pcall(method, HttpService, value)
		if ok then return decoded end
	end
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	value = value:gsub("[^" .. alphabet .. "=]", "")
	return (value:gsub(".", function(character)
		if character == "=" then return "" end
		local index = alphabet:find(character, 1, true) - 1
		local bits = ""
		for position = 6, 1, -1 do
			local enabled = index % 2 ^ position - index % 2 ^ (position - 1) > 0
			bits ..= enabled and "1" or "0"
		end
		return bits
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
		if #bits ~= 8 then return "" end
		local byte = 0
		for position = 1, 8 do
			if bits:sub(position, position) == "1" then byte += 2 ^ (8 - position) end
		end
		return string.char(byte)
	end))
end

local function enumFromValue(current, value)
	if typeof(current) ~= "EnumItem" then return value end
	for _, item in current.EnumType:GetEnumItems() do
		if item.Value == value then return item end
	end
	return current
end

local function decode(value, objects, instance, property)
	if type(value) ~= "table" or not value.t then return value end
	local tag = value.t
	if tag == "ref" then return objects[value.v]
	elseif tag == "bin" then return base64Decode(value.v)
	elseif tag == "enum" then return enumFromValue(instance[property], value.v)
	elseif tag == "v2" then return Vector2.new(value.v[1], value.v[2])
	elseif tag == "v3" then return Vector3.new(value.v[1], value.v[2], value.v[3])
	elseif tag == "c3" then return Color3.new(value.v[1], value.v[2], value.v[3])
	elseif tag == "u" then return UDim.new(value.v[1], value.v[2])
	elseif tag == "u2" then return UDim2.new(value.v[1], value.v[2], value.v[3], value.v[4])
	elseif tag == "cf" then return CFrame.new(table.unpack(value.v))
	elseif tag == "nr" then return NumberRange.new(value.v[1], value.v[2])
	elseif tag == "ns" then
		local points = {}
		for _, point in value.v do points[#points + 1] = NumberSequenceKeypoint.new(point[1], point[2], point[3]) end
		return NumberSequence.new(points)
	elseif tag == "cs" then
		local points = {}
		for _, point in value.v do
			points[#points + 1] = ColorSequenceKeypoint.new(point[1], Color3.new(point[2], point[3], point[4]))
		end
		return ColorSequence.new(points)
	elseif tag == "pp" then
		if not value.v then return PhysicalProperties.new(Enum.Material.Plastic) end
		return PhysicalProperties.new(table.unpack(value.v))
	elseif tag == "font" then
		local weight = enumFromValue(Enum.FontWeight.Regular, value.v[2])
		local style = enumFromValue(Enum.FontStyle.Normal, value.v[3])
		return Font.new(value.v[1], weight, style)
	elseif tag == "v2i" and Vector2int16 then return Vector2int16.new(value.v[1], value.v[2])
	elseif tag == "v3i" and Vector3int16 then return Vector3int16.new(value.v[1], value.v[2], value.v[3])
	elseif tag == "ray" then
		return Ray.new(Vector3.new(value.v[1], value.v[2], value.v[3]), Vector3.new(value.v[4], value.v[5], value.v[6]))
	elseif tag == "bc" then return BrickColor.new(value.v)
	elseif tag == "rect" then return Rect.new(value.v[1], value.v[2], value.v[3], value.v[4])
	end
	return value.v
end

local function assign(instance, property, value, objects)
	local decoded
	local ok = pcall(function() decoded = decode(value, objects, instance, property) end)
	if not ok then return false end
	ok = pcall(function() instance[property] = decoded end)
	if not ok and sethiddenproperty then ok = pcall(sethiddenproperty, instance, property, decoded) end
	return ok
end

local function destination(name, playerGui, storage)
	if name == "PlayerGui" then return playerGui
	elseif name == "Lighting" then return Lighting
	elseif name == "SoundService" then return SoundService
	elseif name == "Workspace" then return workspace
	end
	return storage
end

local function instantiate(pack, playerGui, storage, objects, warnings, marker)
	local localObjects = {}
	for _, record in pack.records do
		local ok, instance = pcall(Instance.new, record[3])
		if ok and instance then
			instance.Name = record[4]
			objects[record[1]] = instance
			localObjects[record[1]] = instance
		else
			warnings[#warnings + 1] = "class:" .. tostring(record[3])
		end
	end
	for _, record in pack.records do
		local instance = localObjects[record[1]]
		if instance then
			for property, value in record[5] do
				if not assign(instance, property, value, objects) then
					warnings[#warnings + 1] = record[3] .. "." .. property
				end
			end
		end
	end
	local target = destination(pack.target, playerGui, storage)
	for _, record in pack.records do
		local instance = localObjects[record[1]]
		if instance then
			local parent = record[2] and localObjects[record[2]] or target
			pcall(function() instance.Parent = parent end)
			if not record[2] and marker then pcall(function() instance:SetAttribute(marker, true) end) end
		end
	end
	return localObjects
end

local function makeNotice(playerGui, opaqueName)
	local gui = Instance.new("ScreenGui")
	gui.Name = opaqueName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	local label = Instance.new("TextLabel")
	label.Name = opaqueName
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.04)
	label.Size = UDim2.fromOffset(620, 44)
	label.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local function makeStatus(playerGui, opaqueName)
	local gui = Instance.new("ScreenGui")
	gui.Name = opaqueName
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local label = Instance.new("TextLabel")
	label.Name = opaqueName
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 18, 1, -18)
	label.Size = UDim2.fromOffset(360, 42)
	label.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
	label.BackgroundTransparency = 0.18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local function showNotice(label, text, duration)
	label.Text = text
	label.Visible = true
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.12
	task.delay(duration or 3, function()
		if label.Text == text then
			local tween = TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 1, BackgroundTransparency = 1})
			tween:Play()
			tween.Completed:Once(function() if label.Text == text then label.Visible = false end end)
		end
	end)
end

local function restoreCharacter(character)
	if not character then return end
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			pcall(function()
				item.Transparency = item.Name == "HumanoidRootPart" and 1 or 0
				item.LocalTransparencyModifier = 0
			end)
		elseif item:IsA("Decal") then
			pcall(function() item.Transparency = 0 end)
		end
	end
end

local function motorMap(character)
	local map = {}
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 then
			map[item.Part1.Name] = item
			map[item.Name] = item
		end
	end
	return map
end

local function animationPlayer(module, index)
	local loaded = {}
	local tracks = setmetatable({}, {__mode = "k"})
	local function get(animationCode)
		local entry = index[animationCode]
		if not entry then return nil end
		if not loaded[entry] then loaded[entry] = module(entry) end
		return loaded[entry]
	end
	local function stop(character)
		local track = tracks[character]
		if track then track.cancelled = true; tracks[character] = nil end
	end
	local function play(character, animationCode, speed)
		local sequence = get(animationCode)
		if not character or not sequence or #sequence.frames == 0 then return end
		stop(character)
		local track = {cancelled = false}
		tracks[character] = track
		local motors = motorMap(character)
		local started = os.clock()
		local length = sequence.frames[#sequence.frames][1]
		speed = math.max(0.05, tonumber(speed) or 1)
		task.spawn(function()
			repeat
				for frameIndex, frame in sequence.frames do
					if track.cancelled or not character.Parent then return end
					local nextFrame = sequence.frames[frameIndex + 1]
					local frameStart = frame[1]
					local frameDuration = nextFrame and math.max(0, nextFrame[1] - frameStart) / speed or 0
					for _, pose in frame[2] do
						local motor = motors[pose[1]]
						if motor then
							local target = CFrame.new(table.unpack(pose[2]))
							if frameDuration > 0 then
								local style = enumFromValue(Enum.EasingStyle.Linear, pose[3])
								local direction = enumFromValue(Enum.EasingDirection.In, pose[4])
								pcall(function() TweenService:Create(motor, TweenInfo.new(frameDuration, style, direction), {Transform = target}):Play() end)
							else
								motor.Transform = target
							end
						end
					end
					if frameDuration > 0 then task.wait(frameDuration) end
				end
			until not sequence.looped or track.cancelled
			if not track.cancelled then
				for _, motor in motors do pcall(function() motor.Transform = CFrame.identity end) end
			end
			if tracks[character] == track then tracks[character] = nil end
		end)
		return length / speed, started
	end
	return {play = play, stop = stop}
end

local function findVisual(objects, id)
	return id and objects[id] or nil
end

local function cloneVisual(objects, id, parent, lifetime)
	local source = findVisual(objects, id)
	if not source or not parent then return nil end
	local clone = source:Clone()
	clone.Name = source.Name
	clone.Parent = parent
	if clone:IsA("Sound") then clone:Play() end
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local count = item:GetAttribute("EmitCount") or item:GetAttribute("emitCount") or 8
			item:Emit(count)
		elseif item:IsA("Sound") then item:Play() end
	end
	game:GetService("Debris"):AddItem(clone, lifetime or 6)
	return clone
end

local function wireTools(playerGui, player, send, objects, assetIndex, names, guard, attackPreview)
	local currentTool
	local function connectTool(tool)
		if tool:GetAttribute(names.runtime_marker) then return end
		tool:SetAttribute(names.runtime_marker, true)
		tool.Activated:Connect(function()
			if not guard() then return end
			if attackPreview then attackPreview() end
			send(23)
		end)
	end
	local gui = assetIndex.gui or {}
	local picker = objects[gui.weapon_picker]
	local opener = objects[gui.weapon_open]
	if picker and picker:IsA("ScreenGui") then picker.Enabled = false end
	if opener and opener:IsA("GuiButton") then
		opener.Activated:Connect(function()
			if not guard() or not picker or not picker.Parent then return end
			picker.Enabled = not picker.Enabled
		end)
	end
	for selection, id in assetIndex.weapon_buttons or {} do
		local chosen = selection
		local button = objects[id]
		if button and button:IsA("GuiButton") then
			button.Activated:Connect(function()
				if not guard() then return end
				if picker and picker.Parent then picker.Enabled = false end
				send(121, chosen)
			end)
		end
	end
	return function(selection)
		local id = assetIndex.weapons and assetIndex.weapons[selection]
		local source = id and objects[id]
		if not source or not source:IsA("Tool") then return end
		if currentTool then currentTool:Destroy() end
		currentTool = source:Clone()
		currentTool.Name = source.Name
		connectTool(currentTool)
		currentTool.Parent = player:WaitForChild("Backpack")
		local character = player.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then pcall(function() humanoid:EquipTool(currentTool) end) end
	end
end

local function wireInterface(player, send, objects, assetIndex, names, guard)
	local gui = assetIndex.gui or {}
	local function get(key) return objects[gui[key]] end
	local function connect(button, callback)
		if button and button:IsA("GuiButton") then
			button.Activated:Connect(function(...)
				if guard() then callback(...) end
			end)
		end
	end
	local function play(sound)
		if sound and sound:IsA("Sound") then
			pcall(function() sound.TimePosition = 0; sound:Play() end)
		end
	end

	local hitboxes = false
	local hitboxLabel = get("hitbox_label")
	local function setHitboxes(value)
		hitboxes = value
		if hitboxLabel and hitboxLabel:IsA("TextLabel") then
			hitboxLabel.Text = value and "Hitboxes: On" or "Hitboxes: Off"
		end
	end
	setHitboxes(false)
	connect(get("hitbox_button"), function()
		setHitboxes(not hitboxes)
		play(get("hitbox_sound"))
	end)
	local function attackPreview()
		if not hitboxes then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local box = Instance.new("Part")
		box.Name = names.transient_visual
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Material = Enum.Material.ForceField
		box.Color = Color3.fromRGB(255, 64, 96)
		box.Transparency = 0.62
		box.Size = Vector3.new(3, 5, 3)
		box.CFrame = root.CFrame * CFrame.new(0, 0, -2)
		box.Parent = workspace
		game:GetService("Debris"):AddItem(box, 0.10)
	end

	local emoteDisplay = get("emotes_display")
	local emotesOpen = false
	connect(get("emotes_toggle"), function()
		emotesOpen = not emotesOpen
		if emoteDisplay and emoteDisplay:IsA("GuiObject") then
			TweenService:Create(emoteDisplay, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = emotesOpen and UDim2.new(0.5, 0, 0.6, 0) or UDim2.new(0.5, 0, 1.3, 0),
			}):Play()
		end
	end)
	for index, id in assetIndex.emote_buttons or {} do
		local code = 80 + index
		connect(objects[id], function() send(code) end)
	end

	local genderGui = get("gender_gui")
	if genderGui and genderGui:IsA("ScreenGui") then
		genderGui.Enabled = player:GetAttribute(names.state_gender) == nil
	end
	for index, id in assetIndex.gender_buttons or {} do
		local code = 112 + index
		connect(objects[id], function() send(code) end)
	end
	local function genderSelected()
		if genderGui and genderGui.Parent then genderGui.Enabled = false end
	end

	local mobileGui = get("mobile_gui")
	if mobileGui and mobileGui:IsA("ScreenGui") then mobileGui.Enabled = UserInputService.TouchEnabled end
	connect(get("mobile_dash"), function() play(get("mobile_dash") and get("mobile_dash"):FindFirstChildWhichIsA("Sound")); send(49) end)
	connect(get("mobile_getup"), function() play(get("mobile_getup") and get("mobile_getup"):FindFirstChildWhichIsA("Sound")); send(65) end)

	local meter = 0
	local meterBar = get("meter_bar")
	local meterLabel = get("meter_label")
	local meterFlash = get("meter_flash")
	local function setMeter(value)
		meter = math.clamp(tonumber(value) or 0, 0, 1)
		if meterBar and meterBar:IsA("GuiObject") then
			TweenService:Create(meterBar, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = UDim2.new(1, 0, meter, 0),
			}):Play()
		end
		if meterLabel and meterLabel:IsA("TextLabel") then
			meterLabel.Visible = meter >= 0.26
			meterLabel.Text = meter >= 0.98 and "R - RELEASE" or (meter >= 0.26 and "R - Faster" or "")
		end
	end
	local function phaseFeedback()
		if meter < 0.26 then return end
		play(get("meter_sound"))
		if meterLabel and meterLabel:IsA("TextLabel") then
			TweenService:Create(meterLabel, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
			task.delay(0.28, function()
				if guard() and meterLabel.Parent then meterLabel.TextTransparency = 0 end
			end)
		end
		if meter >= 0.98 and meterFlash and meterFlash:IsA("ImageLabel") then
			meterFlash.Visible = true
			meterFlash.ImageTransparency = 0
			TweenService:Create(meterFlash, TweenInfo.new(1), {ImageTransparency = 1}):Play()
			task.delay(1, function() if meterFlash.Parent then meterFlash.Visible = false end end)
		end
	end
	connect(get("mobile_phase"), function() phaseFeedback(); send(97) end)

	local getupPanel = get("getup_panel")
	local getupBar = get("getup_bar")
	local function recoveryProgress(count)
		local progress = math.clamp((tonumber(count) or 0) / 20, 0, 1)
		if getupPanel and getupPanel:IsA("GuiObject") then
			TweenService:Create(getupPanel, TweenInfo.new(0.25), {
				Position = progress > 0 and UDim2.new(0.5, 0, 1, -50) or UDim2.new(0.5, 0, 1, 50),
			}):Play()
		end
		if getupBar and getupBar:IsA("GuiObject") then
			TweenService:Create(getupBar, TweenInfo.new(0.2), {Size = UDim2.new(progress, 0, 1, 0)}):Play()
		end
	end

	local shiftGui = get("shiftlock_gui")
	local shiftButton = get("shiftlock_button")
	if shiftGui and shiftGui:IsA("ScreenGui") then shiftGui.Enabled = UserInputService.TouchEnabled end
	local shiftConnection
	connect(shiftButton, function()
		if shiftConnection then
			shiftConnection:Disconnect()
			shiftConnection = nil
			local character = player.Character
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then humanoid.AutoRotate = true end
			if shiftButton:IsA("ImageButton") then shiftButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png" end
			return
		end
		if shiftButton:IsA("ImageButton") then shiftButton.Image = "rbxasset://textures/ui/mouseLock_on@2x.png" end
		shiftConnection = RunService.RenderStepped:Connect(function()
			if not guard() then shiftConnection:Disconnect(); shiftConnection = nil; return end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			local camera = workspace.CurrentCamera
			if root and humanoid and camera then
				humanoid.AutoRotate = false
				local look = camera.CFrame.LookVector
				root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
			end
		end)
	end)

	local voteGui = get("vote_gui")
	local voteFrame = get("vote_frame")
	local voteContainer = get("vote_container")
	local voteTemplate = get("vote_template")
	if voteGui and voteGui:IsA("ScreenGui") then voteGui.Enabled = false end
	if voteTemplate and voteTemplate:IsA("GuiObject") then voteTemplate.Visible = false end
	local voteFrames = {}
	local function clearVotes()
		for _, entry in voteFrames do
			if entry[1] and entry[1].Parent then entry[1]:Destroy() end
		end
		table.clear(voteFrames)
	end
	local function beginVote(tokens, labels)
		clearVotes()
		if not voteGui or not voteFrame or not voteContainer or not voteTemplate then return end
		voteGui.Enabled = true
		voteFrame.Visible = true
		local sourceName = get("vote_map_name")
		local sourceButton = get("vote_button")
		local sourceCount = get("vote_count")
		for index, token in tokens do
			local choice = index
			local frame = voteTemplate:Clone()
			frame.Name = voteTemplate.Name
			frame.Visible = true
			local label = sourceName and frame:FindFirstChild(sourceName.Name, true)
			local button = sourceButton and frame:FindFirstChild(sourceButton.Name, true)
			local count = sourceCount and frame:FindFirstChild(sourceCount.Name, true)
			if label and label:IsA("TextLabel") then label.Text = labels[token] or ("Map " .. index) end
			if count and count:IsA("TextLabel") then count.Text = "Votes: 0" end
			connect(button, function() send(96, choice) end)
			frame.Parent = voteContainer
			voteFrames[index] = {frame, count}
		end
	end
	local function updateVotes(public)
		local totals = {}
		local votes = type(public) == "table" and public or {}
		for _, choice in votes do totals[choice] = (totals[choice] or 0) + 1 end
		for index, entry in voteFrames do
			if entry[2] and entry[2].Parent then entry[2].Text = "Votes: " .. tostring(totals[index] or 0) end
		end
	end
	local function endVote()
		if voteGui and voteGui.Parent then voteGui.Enabled = false end
		clearVotes()
	end

	return {
		attackPreview = attackPreview,
		genderSelected = genderSelected,
		setMeter = setMeter,
		phaseFeedback = phaseFeedback,
		recoveryProgress = recoveryProgress,
		beginVote = beginVote,
		updateVotes = updateVotes,
		endVote = endVote,
	}
end

local function worldWeaponBridge(objects, assetIndex, names, localPlayer, guard)
	local current = setmetatable({}, {__mode = "k"})
	local selected = setmetatable({}, {__mode = "k"})
	local function attach(owner, selection)
		if not guard() then return end
		selected[owner] = selection
		if owner == localPlayer then return end
		local previous = current[owner]
		if previous then
			if previous[1] then previous[1]:Destroy() end
			if previous[2] then previous[2]:Destroy() end
			current[owner] = nil
		end
		local character = owner.Character
		local source = objects[assetIndex.weapons and assetIndex.weapons[selection]]
		if not character or not source or not source:IsA("Tool") then return end
		local hand = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		local copy = source:Clone()
		local handle = copy:FindFirstChild("Handle", true)
		if not hand or not handle or not handle:IsA("BasePart") then copy:Destroy(); return end
		copy.Name = source.Name
		copy.RequiresHandle = false
		copy.Parent = character
		for _, item in copy:GetDescendants() do
			if item:IsA("BasePart") then item.CanCollide = false; item.Massless = true end
		end
		handle.CFrame = hand.CFrame
		local joint = Instance.new("Motor6D")
		joint.Name = names.transient_visual
		joint.Part0 = hand
		joint.Part1 = handle
		joint.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		joint.C1 = source.Grip
		joint.Parent = hand
		current[owner] = {copy, joint}
	end
	local function track(owner)
		owner.CharacterAdded:Connect(function()
			if not guard() then return end
			local selection = selected[owner] or owner:GetAttribute(names.state_weapon)
			if selection and selection > 0 then task.delay(0.2, attach, owner, selection) end
		end)
	end
	for _, owner in Players:GetPlayers() do track(owner) end
	Players.PlayerAdded:Connect(track)
	return attach
end

local function morphBridge(objects, assetIndex, names)
	local active = setmetatable({}, {__mode = "k"})
	local saved = setmetatable({}, {__mode = "k"})
	local function clear(character)
		if not character then return end
		local record = active[character]
		if record then
			if record[1] then record[1]:Destroy() end
			if record[2] then record[2]:Destroy() end
			active[character] = nil
		end
		local state = saved[character]
		if state then
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if torso then pcall(function() torso.LocalTransparencyModifier = state[1] end) end
			if state[2] and state[2].Parent then pcall(function() state[2].ShirtTemplate = state[3] end) end
			if state[4] and state[4].Parent then pcall(function() state[4].PantsTemplate = state[5] end) end
			saved[character] = nil
		end
	end
	local function apply(character, selection)
		if not character then return end
		clear(character)
		local source = objects[assetIndex.morphs and assetIndex.morphs[selection]]
		local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
		if not source or not source:IsA("Model") or not torso or not torso:IsA("BasePart") then return end
		local shirt = character:FindFirstChildWhichIsA("Shirt")
		local pants = character:FindFirstChildWhichIsA("Pants")
		saved[character] = {
			torso.LocalTransparencyModifier,
			shirt, shirt and shirt.ShirtTemplate or nil,
			pants, pants and pants.PantsTemplate or nil,
		}
		if shirt then pcall(function() shirt.ShirtTemplate = "" end) end
		if pants then pcall(function() pants.PantsTemplate = "" end) end
		local copy = source:Clone()
		copy.Name = names.transient_visual
		copy.Parent = character
		local anchorName = assetIndex.morph_anchors and assetIndex.morph_anchors[selection]
		local anchor = anchorName and copy:FindFirstChild(anchorName, true)
		if not anchor or not anchor:IsA("BasePart") then copy:Destroy(); clear(character); return end
		local tint = {}
		for _, name in assetIndex.morph_tint_names and assetIndex.morph_tint_names[selection] or {} do tint[name] = true end
		for _, item in copy:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.Massless = true
				if tint[item.Name] then item.Color = torso.Color end
			elseif item:IsA("Motor6D") and not item.Part0 then
				item.Part0 = torso
			end
		end
		anchor.CFrame = torso.CFrame
		local joint = Instance.new("WeldConstraint")
		joint.Name = names.transient_visual
		joint.Part0 = torso
		joint.Part1 = anchor
		joint.Parent = torso
		torso.LocalTransparencyModifier = 1
		active[character] = {copy, joint}
	end
	return apply, clear
end

function Core.start(context)
	local protocol, names, module = context.protocol, context.names, context.module
	local environment = context.environment or ((getgenv and getgenv()) or _G)
	local runToken = context.run_token or HttpService:GenerateGUID(false)
	environment.FUNCOMBAT_RUNTIME_RUN = runToken
	local function guard() return environment.FUNCOMBAT_RUNTIME_RUN == runToken end
	local player = Players.LocalPlayer
	assert(player, "Fun Combat runtime requires a local player")
	local playerGui = player:WaitForChild("PlayerGui")
	local protocolFolder = ReplicatedStorage:WaitForChild(names.protocol_folder, 15)
	assert(protocolFolder, "Fun Combat server protocol was not found")
	local actionEvent = protocolFolder:WaitForChild(names.action_event, 10)
	local handshake = protocolFolder:WaitForChild(names.handshake_function, 10)
	assert(actionEvent and handshake, "Fun Combat server protocol is incomplete")
	local ok, compatible, gameBuild, protocolVersion, runtimeVersion, assetVersion = pcall(
		function()
			return handshake:InvokeServer(protocol.GAME_BUILD, protocol.PROTOCOL_VERSION,
				protocol.RUNTIME_VERSION, protocol.ASSET_VERSION)
		end)
	assert(ok, "Fun Combat compatibility handshake failed: " .. tostring(compatible))
	assert(compatible,
		("Incompatible Fun Combat runtime. Server=%s/%s/%s/%s Runtime=%s/%s/%s/%s")
		:format(tostring(gameBuild), tostring(protocolVersion), tostring(runtimeVersion), tostring(assetVersion),
			tostring(protocol.GAME_BUILD), tostring(protocol.PROTOCOL_VERSION), tostring(protocol.RUNTIME_VERSION), tostring(protocol.ASSET_VERSION)))

	local assetIndex = module("assets/index.lua")
	local cleanupNames = {
		[names.runtime_root] = true,
		[names.runtime_notice] = true,
		[names.runtime_status] = true,
		[names.transient_visual] = true,
	}
	for _, name in assetIndex.cleanup_root_names or {} do cleanupNames[name] = true end
	for _, service in {playerGui, Lighting, SoundService, workspace} do
		for _, item in service:GetChildren() do
			if cleanupNames[item.Name] or item:GetAttribute(names.runtime_marker) then item:Destroy() end
		end
	end
	local storage = Instance.new("Folder")
	storage.Name = names.runtime_root
	storage:SetAttribute(names.runtime_marker, true)
	storage.Parent = playerGui
	local notice = makeNotice(playerGui, names.runtime_notice)
	local status = makeStatus(playerGui, names.runtime_status)
	notice.Parent:SetAttribute(names.runtime_marker, true)
	status.Parent:SetAttribute(names.runtime_marker, true)
	local statusState = {
		health = 100,
		kills = player:GetAttribute(names.state_kills) or 0,
		streak = player:GetAttribute(names.state_streak) or 0,
	}
	local function updateStatus()
		status.Text = ("HP %d   Kills %d   Streak %d"):format(
			math.max(0, math.floor(statusState.health + 0.5)), statusState.kills, statusState.streak)
	end
	updateStatus()
	local objects, warnings = {}, {}
	local assetManifest = module("assets/manifest.lua")
	for _, path in assetManifest do
		local pack = module(path)
		instantiate(pack, playerGui, storage, objects, warnings, names.runtime_marker)
	end
	local animationIndex = module("animations/index.lua")
	local animations = animationPlayer(module, animationIndex)
	local activeWeather = {}
	local function clearWeather()
		for _, item in activeWeather do if item and item.Parent then item:Destroy() end end
		table.clear(activeWeather)
	end
	local function applyWeather(weatherCode)
		clearWeather()
		local source = objects[assetIndex.weather and assetIndex.weather[weatherCode]]
		if not source then return end
		for _, item in source:GetChildren() do
			local copy = item:Clone()
			copy.Name = item.Name
			copy:SetAttribute(names.runtime_marker, true)
			copy.Parent = copy:IsA("Model") and workspace or Lighting
			activeWeather[#activeWeather + 1] = copy
		end
	end
	local musicTemplate = objects[assetIndex.music]
	if musicTemplate and musicTemplate:IsA("Sound") then
		local music = musicTemplate:Clone()
		music.Name = names.transient_visual
		music:SetAttribute(names.runtime_marker, true)
		music.Parent = SoundService
		task.spawn(function()
			while music.Parent and guard() do
				local list = assetIndex.playlist
				if list and #list > 0 then music.SoundId = "rbxassetid://" .. list[math.random(1, #list)] end
				music:Play()
				music.Ended:Wait()
				task.wait(3)
			end
		end)
	end
	applyWeather(1)

	local function send(code, value) actionEvent:FireServer(code, value) end
	local interface = wireInterface(player, send, objects, assetIndex, names, guard)
	local equipLocalWeapon = wireTools(
		playerGui, player, send, objects, assetIndex, names, guard, interface.attackPreview
	)
	local attachWorldWeapon = worldWeaponBridge(objects, assetIndex, names, player, guard)
	local applyMorph, clearMorph = morphBridge(objects, assetIndex, names)

	local function translatePrompt(prompt)
		local translation = names.prompt_text[prompt.Name]
		if translation then
			pcall(function()
				prompt.ActionText = translation[1]
				prompt.ObjectText = translation[2]
			end)
		end
	end
	for _, item in game:GetDescendants() do if item:IsA("ProximityPrompt") then translatePrompt(item) end end
	game.DescendantAdded:Connect(function(item)
		if guard() and item:IsA("ProximityPrompt") then translatePrompt(item) end
	end)

	local decorated = setmetatable({}, {__mode = "k"})
	local function decorate(character)
		if not guard() then return end
		task.wait()
		if not guard() then return end
		restoreCharacter(character)
		if not decorated[character] then
			decorated[character] = true
			character.DescendantAdded:Connect(function(item)
				if not guard() then return end
				if item:IsA("BasePart") or item:IsA("Decal") then
					task.defer(function()
						if item.Parent and not item:FindFirstAncestor(names.transient_visual) then restoreCharacter(character) end
					end)
				end
			end)
		end
		if character == player.Character then
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				statusState.health = humanoid.Health
				updateStatus()
					humanoid.HealthChanged:Connect(function(value)
						if not guard() then return end
					statusState.health = value
					updateStatus()
				end)
			end
		end
	end
	if player.Character then task.spawn(decorate, player.Character) end
	player.CharacterAdded:Connect(decorate)
	for _, other in Players:GetPlayers() do
		if other.Character then task.spawn(decorate, other.Character) end
		other.CharacterAdded:Connect(decorate)
	end
	Players.PlayerAdded:Connect(function(other) other.CharacterAdded:Connect(decorate) end)
	for _, owner in Players:GetPlayers() do
		local selection = owner:GetAttribute(names.state_weapon)
		if selection and selection > 0 then
			if owner == player then equipLocalWeapon(selection) else attachWorldWeapon(owner, selection) end
		end
	end

	actionEvent.OnClientEvent:Connect(function(code, a, b, c, d, e)
		if not guard() then return end
		if code == 129 then
			if b == names.state_weapon then
				if a == player then equipLocalWeapon(c) else attachWorldWeapon(a, c) end
			end
			if b == names.state_gender and a == player then interface.genderSelected() end
			if a == player then
				if b == names.state_kills then statusState.kills = c end
				if b == names.state_streak then statusState.streak = c end
				if d == names.state_streak then statusState.streak = e end
				updateStatus()
			end
			if a == player.Character and b == names.state_meter then
				local meter = tonumber(c) or 0
				interface.setMeter(meter)
				if meter >= 0.98 then showNotice(notice, "R - RELEASE", 0.5)
				elseif meter >= 0.60 then showNotice(notice, "R - Faster", 0.5)
				elseif meter >= 0.26 then showNotice(notice, "R - Faster", 0.5) end
			end
		elseif code == 130 then
			local victim, visualCode = b, c
			local root = victim and (victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart"))
			if root then
				cloneVisual(objects, assetIndex.effects[visualCode], root, 5)
				cloneVisual(objects, assetIndex.sounds[visualCode], root, 5)
				local highlight = Instance.new("Highlight")
				highlight.Name = names.transient_visual
				highlight.FillColor = visualCode == 2 and Color3.fromRGB(255, 88, 130) or Color3.new(0, 0, 0)
				highlight.OutlineColor = visualCode == 2 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.45
				highlight.Parent = victim
				game:GetService("Debris"):AddItem(highlight, 0.6)
			end
			animations.play(victim, visualCode == 2 and 13 or (visualCode == 3 and 12 or 11), 1)
		elseif code == 131 then
			animations.play(a, b, c)
		elseif code == 132 then
			local root = a and (a:FindFirstChild("HumanoidRootPart") or a)
			cloneVisual(objects, assetIndex.sounds[b], root, 6)
		elseif code == 133 then
			local root = a and (a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("Torso") or a)
			cloneVisual(objects, assetIndex.effects[b], root, 7)
			if b == 9 and a then
				local highlight = Instance.new("Highlight")
				highlight.Name = names.transient_visual
				highlight.FillColor = Color3.new(1, 1, 1)
				highlight.OutlineColor = Color3.new(0, 0, 0)
				highlight.Parent = a
				game:GetService("Debris"):AddItem(highlight, 0.8)
			end
		elseif code == 134 and a == 1 then
			interface.recoveryProgress(b)
			showNotice(notice, ("Recover: %d/20"):format(b), 0.4)
		elseif code == 134 and a == 2 then
			showNotice(notice, b == 1 and "You can't hide forever." or "...", 3)
		elseif code == 136 then
			if b then task.spawn(decorate, b) end
		elseif code == 137 then
			if a == 1 then
				applyMorph(b, d)
				applyMorph(c, e)
			else
				clearMorph(b)
				clearMorph(c)
			end
		elseif code == 144 then
			local labels = {}
			for index, token in a do labels[index] = names.maps[token] or ("Map " .. index) end
			interface.beginVote(a, names.maps)
			showNotice(notice, "Vote: 1=" .. (labels[1] or "-") .. "  2=" .. (labels[2] or "-"), 15)
		elseif code == 145 then
			interface.updateVotes(a)
		elseif code == 146 then
			interface.endVote()
			showNotice(notice, "Map selected", 3)
		elseif code == 147 then
			applyWeather(a)
			showNotice(notice, "Weather changed", 2)
		elseif code == 255 then
			showNotice(notice, "Server rejected action " .. tostring(a), 2)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not guard() or processed then return end
		local character = player.Character
		if input.KeyCode == Enum.KeyCode.Q then send(49)
		elseif input.KeyCode == Enum.KeyCode.G then
			if character and character:GetAttribute(names.state_down) then send(65) else send(81) end
		elseif input.KeyCode == Enum.KeyCode.H then send(82)
		elseif input.KeyCode == Enum.KeyCode.J then send(83)
		elseif input.KeyCode == Enum.KeyCode.K then send(84)
		elseif input.KeyCode == Enum.KeyCode.L then send(85)
		elseif input.KeyCode == Enum.KeyCode.R then interface.phaseFeedback(); send(97)
		elseif input.KeyCode == Enum.KeyCode.One and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then send(96, 1)
		elseif input.KeyCode == Enum.KeyCode.Two and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then send(96, 2)
		end
	end)

	showNotice(notice, "Fun Combat runtime connected", 3)
	if #warnings > 0 then warn("Fun Combat runtime skipped " .. #warnings .. " unsupported properties; see validation report") end
	return {objects = objects, warnings = warnings, stopAnimation = animations.stop}
end

return Core
