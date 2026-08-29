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
			if instance:IsA("ScreenGui") then instance.ResetOnSpawn = false end
			if instance:IsA("Sound") then
				pcall(function()
					instance:Stop()
					instance.TimePosition = 0
				end)
			end
		end
	end
	local target = destination(pack.target, playerGui, storage)
	for _, record in pack.records do
		local instance = localObjects[record[1]]
		if instance then
			local parent = record[2] and localObjects[record[2]] or target
			pcall(function() instance.Parent = parent end)
			if instance:IsA("Sound") then
				pcall(function()
					instance:Stop()
					instance.TimePosition = 0
				end)
			end
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

local function animationPlayer(module, index, visualMotorMap)
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
		if not track then return end
		track.cancelled = true
		for _, tween in track.tweens do pcall(function() tween:Cancel() end) end
		for _, motor in track.motors do pcall(function() motor.Transform = CFrame.identity end) end
		tracks[character] = nil
	end
	local function play(character, animationCode, speed)
		local sequence = get(animationCode)
		if not character or not sequence or #sequence.frames == 0 then return end
		stop(character)
		local motors = motorMap(character)
		if visualMotorMap then
			for key, motor in visualMotorMap(character) or {} do motors[key] = motor end
		end
		local track = {cancelled = false, tweens = {}, motors = motors}
		tracks[character] = track
		local started = os.clock()
		local length = sequence.frames[#sequence.frames][1]
		speed = math.max(0.05, tonumber(speed) or 1)
		task.spawn(function()
			repeat
				local previousTime = 0
				for _, frame in sequence.frames do
					if track.cancelled or not character.Parent then return end
					local frameDuration = math.max(0, frame[1] - previousTime) / speed
					local transitions = {}
					for _, pose in frame[2] do
						local motor = motors[pose[1]]
						if motor then
							local target = CFrame.new(table.unpack(pose[2]))
							transitions[#transitions + 1] = {
								motor, motor.Transform, target,
								enumFromValue(Enum.EasingStyle.Linear, pose[3]),
								enumFromValue(Enum.EasingDirection.In, pose[4]),
							}
						end
					end
					if frameDuration <= 0 then
						for _, transition in transitions do transition[1].Transform = transition[3] end
					else
						local elapsed = 0
						while elapsed < frameDuration do
							if track.cancelled or not character.Parent then return end
							elapsed += RunService.RenderStepped:Wait()
							local alpha = math.clamp(elapsed / frameDuration, 0, 1)
							for _, transition in transitions do
								local eased = TweenService:GetValue(alpha, transition[4], transition[5])
								transition[1].Transform = transition[2]:Lerp(transition[3], eased)
							end
						end
					end
					previousTime = frame[1]
				end
			until not sequence.looped or track.cancelled
			if not track.cancelled then
				for _, motor in motors do pcall(function() motor.Transform = CFrame.identity end) end
			end
			if tracks[character] == track then tracks[character] = nil end
		end)
		return length / speed, started
	end
	local function isPlaying(character) return tracks[character] ~= nil end
	return {play = play, stop = stop, isPlaying = isPlaying}
end

local function locomotionBridge(animations, names, guard)
	local cached = setmetatable({}, {__mode = "k"})
	local clock = 0
	local function target(motor, transform, alpha)
		if motor and motor.Enabled then motor.Transform = motor.Transform:Lerp(transform, alpha) end
	end
	RunService.RenderStepped:Connect(function(delta)
		if not guard() then return end
		clock += delta
		local alpha = math.clamp(delta * 12, 0, 1)
		for _, owner in Players:GetPlayers() do
			local character = owner.Character
			if not character or animations.isPlaying(character) then continue end
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or humanoid.Health <= 0 then continue end
			local animator = humanoid:FindFirstChildWhichIsA("Animator")
			local hasEngineTrack = false
			if animator then pcall(function() hasEngineTrack = #animator:GetPlayingAnimationTracks() > 0 end) end
			if hasEngineTrack then continue end
			local motors = cached[character]
			if not motors then motors = motorMap(character); cached[character] = motors end
			local blocked = character:GetAttribute(names.state_down) or character:GetAttribute(names.state_busy)
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local state = humanoid:GetState()
			local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
			local rightArm, leftArm = motors["Right Arm"], motors["Left Arm"]
			local rightLeg, leftLeg = motors["Right Leg"], motors["Left Leg"]
			if blocked then
				target(rightArm, CFrame.identity, alpha); target(leftArm, CFrame.identity, alpha)
				target(rightLeg, CFrame.identity, alpha); target(leftLeg, CFrame.identity, alpha)
			elseif airborne then
				target(rightArm, CFrame.Angles(-0.35, 0, 0.15), alpha)
				target(leftArm, CFrame.Angles(-0.35, 0, -0.15), alpha)
				target(rightLeg, CFrame.Angles(0.2, 0, 0), alpha)
				target(leftLeg, CFrame.Angles(-0.2, 0, 0), alpha)
			elseif speed > 1 then
				local phase = clock * math.clamp(speed * 0.75, 6, 13)
				local swing = math.sin(phase) * math.clamp(speed / 16, 0.35, 1) * 0.85
				target(rightArm, CFrame.Angles(swing, 0, 0), alpha)
				target(leftArm, CFrame.Angles(-swing, 0, 0), alpha)
				target(rightLeg, CFrame.Angles(-swing, 0, 0), alpha)
				target(leftLeg, CFrame.Angles(swing, 0, 0), alpha)
			else
				local breathe = math.sin(clock * 1.8) * 0.035
				target(rightArm, CFrame.Angles(breathe, 0, 0.03), alpha)
				target(leftArm, CFrame.Angles(-breathe, 0, -0.03), alpha)
				target(rightLeg, CFrame.identity, alpha)
				target(leftLeg, CFrame.identity, alpha)
			end
		end
	end)
end

local function findVisual(objects, id)
	return id and objects[id] or nil
end

local function cloneVisual(objects, id, parent, lifetime, marker)
	local source = findVisual(objects, id)
	if not source or not parent then return nil end
	local clone = source:Clone()
	clone.Name = source.Name
	if marker then clone:SetAttribute(marker, true) end
	clone.Parent = parent
	if clone:IsA("ParticleEmitter") then
		clone:Emit(clone:GetAttribute("EmitCount") or clone:GetAttribute("emitCount") or 8)
	elseif clone:IsA("Sound") then
		clone.TimePosition = 0
		clone:Play()
	end
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local count = item:GetAttribute("EmitCount") or item:GetAttribute("emitCount") or 8
			item:Emit(count)
		elseif item:IsA("Sound") then item:Play() end
	end
	game:GetService("Debris"):AddItem(clone, lifetime or 6)
	return clone
end

local function newWindowController()
	local closers = {}
	local function register(key, closer)
		closers[key] = closer
	end
	local function closeAll(except)
		for key, closer in closers do
			if key ~= except then pcall(closer, true) end
		end
	end
	return {register = register, closeAll = closeAll}
end

local function wireTools(playerGui, player, send, objects, assetIndex, names, guard, attackPreview, windows, characterVisuals)
	local currentTool
	local currentJoint
	local lastActivation = 0
	local lastDash = 0
	local connectedTools = setmetatable({}, {__mode = "k"})
	local function activate()
		if not guard() or os.clock() - lastActivation < 0.08 then return end
		lastActivation = os.clock()
		if attackPreview then attackPreview() end
		send(23)
	end
	local function connectTool(tool)
		if connectedTools[tool] then return end
		connectedTools[tool] = true
		tool.Activated:Connect(function()
			activate()
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not currentTool or not player.Character or currentTool.Parent ~= player.Character then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			activate()
		elseif input.KeyCode == Enum.KeyCode.Q and os.clock() - lastDash >= 0.12 then
			lastDash = os.clock()
			send(49)
		end
	end)
	local gui = assetIndex.gui or {}
	local picker = objects[gui.weapon_picker]
	local opener = objects[gui.weapon_open]
	local function closePicker()
		if picker and picker:IsA("ScreenGui") and picker.Parent then picker.Enabled = false end
	end
	closePicker()
	windows.register("weapon", closePicker)
	if opener and opener:IsA("GuiButton") then
		opener.Activated:Connect(function()
			if not guard() or not picker or not picker.Parent then return end
			if picker.Enabled then
				closePicker()
			else
				windows.closeAll("weapon")
				picker.Enabled = true
			end
		end)
	end
	for selection, id in assetIndex.weapon_buttons or {} do
		local chosen = selection
		local button = objects[id]
		if button and button:IsA("GuiButton") then
			button.Activated:Connect(function()
				if not guard() then return end
				closePicker()
				send(121, chosen)
			end)
		end
	end
	local function equip(selection)
		local id = assetIndex.weapons and assetIndex.weapons[selection]
		local source = id and objects[id]
		if not source or not source:IsA("Tool") then return end
		if currentJoint then currentJoint:Destroy(); currentJoint = nil end
		if currentTool then currentTool:Destroy() end
		currentTool = source:Clone()
		currentTool.Name = source.Name
		currentTool:SetAttribute(names.runtime_marker, true)
		for _, item in currentTool:GetDescendants() do
			if item:IsA("Trail") then item.Enabled = false end
		end
		connectTool(currentTool)
		currentTool.Parent = player:WaitForChild("Backpack")
		local character = player.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			pcall(function() humanoid:EquipTool(currentTool) end)
			task.defer(function()
				if not currentTool or not currentTool.Parent or not character then return end
				local handle = currentTool:FindFirstChild("Handle", true)
				local visualHand = characterVisuals and characterVisuals.part(character, "Right Arm")
				if not handle or not handle:IsA("BasePart") or not visualHand then return end
				local joint
				for _, item in character:GetDescendants() do
					if item:IsA("Motor6D") and item.Part1 == handle then
						joint = item
						break
					end
				end
				if joint then
					joint.Part0 = visualHand
				else
					handle.CFrame = visualHand.CFrame
					joint = Instance.new("Motor6D")
					joint.Name = names.transient_visual
					joint.Part0 = visualHand
					joint.Part1 = handle
					joint.C0 = CFrame.new(0, -1, 0)
					joint.C1 = source.Grip
					joint.Parent = visualHand
				end
				joint:SetAttribute(names.runtime_marker, true)
				currentJoint = joint
			end)
		end
	end
	local function pulse()
		if not currentTool or not currentTool.Parent then return end
		for _, item in currentTool:GetDescendants() do
			if item:IsA("Trail") then
				item.Enabled = true
				task.delay(0.5, function() if item.Parent then item.Enabled = false end end)
			end
		end
	end
	return {equip = equip, pulse = pulse}
end

local function wireInterface(player, send, objects, assetIndex, names, guard, windows)
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
	local function float(guiObject, position, rotation, delayTime, duration)
		if not guiObject or not guiObject:IsA("GuiObject") then return end
		TweenService:Create(guiObject, TweenInfo.new(duration or 1.5, Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut, -1, true), {Position = position}):Play()
		task.delay(delayTime or 0.35, function()
			if guard() and guiObject.Parent then
				TweenService:Create(guiObject, TweenInfo.new(duration or 1.5, Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut, -1, true), {Rotation = rotation or -3}):Play()
			end
		end)
	end

	float(get("title_primary"), UDim2.new(0.5, 0, 0, 50), -5, 0.3, 1)
	float(get("title_secondary"), UDim2.new(0.5, 0, 0, 75), -5, 0.3, 1)
	float(get("title_tertiary"), UDim2.new(0.5, 0, 0, 100), -5, 0.3, 1)
	float(get("hitbox_button"), UDim2.new(1, -150, 0.75, 0), 4, 0.6, 1.7)
	float(get("meter_frame"), UDim2.new(0, 30, 0.55, 0), -3, 0.6, 2)
	float(get("emotes_toggle") and get("emotes_toggle").Parent, UDim2.new(0, 30, 0, 10), -2, 0.4, 1.3)
	local subtitle = get("subtitle_label")
	local subtitleSerial = 0
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.Text = ""
		subtitle.TextTransparency = 1
		subtitle.TextStrokeTransparency = 1
	end
	local function showSubtitle(text, duration)
		if not subtitle or not subtitle.Parent then return end
		subtitleSerial += 1
		local serial = subtitleSerial
		subtitle.Text = tostring(text)
		TweenService:Create(subtitle, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			TextTransparency = 0, TextStrokeTransparency = 0,
		}):Play()
		task.delay(duration or 3, function()
			if serial ~= subtitleSerial or not subtitle.Parent then return end
			TweenService:Create(subtitle, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextTransparency = 1, TextStrokeTransparency = 1,
			}):Play()
		end)
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
	local function closeEmotes(instant)
		emotesOpen = false
		if emoteDisplay and emoteDisplay:IsA("GuiObject") and emoteDisplay.Parent then
			local target = UDim2.new(0.5, 0, 1.3, 0)
			if instant then
				emoteDisplay.Position = target
			else
				TweenService:Create(emoteDisplay, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Position = target,
				}):Play()
			end
		end
	end
	closeEmotes(true)
	windows.register("emotes", closeEmotes)
	connect(get("emotes_toggle"), function()
		if emotesOpen then play(get("emotes_off_sound")); closeEmotes(); return end
		windows.closeAll("emotes")
		emotesOpen = true
		play(get("emotes_on_sound"))
		if emoteDisplay and emoteDisplay:IsA("GuiObject") then
			TweenService:Create(emoteDisplay, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.6, 0),
			}):Play()
		end
	end)
	for index, id in assetIndex.emote_buttons or {} do
		local code = 80 + index
		connect(objects[id], function()
			send(code)
			closeEmotes()
		end)
	end

	local genderGui = get("gender_gui")
	if genderGui and genderGui:IsA("ScreenGui") then
		genderGui.Enabled = player:GetAttribute(names.state_gender) == nil
	end
	local function genderSelected()
		if genderGui and genderGui.Parent then genderGui.Enabled = false end
	end
	for index, id in assetIndex.gender_buttons or {} do
		local code = 112 + index
		local button = objects[id]
		if button and button:IsA("GuiButton") then
			button.MouseEnter:Connect(function()
				if not guard() then return end
				play(get("gender_hover_sound"))
				TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
					Rotation = -3,
				}):Play()
			end)
			button.MouseLeave:Connect(function()
				if guard() then
					TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
						Rotation = 0,
					}):Play()
				end
			end)
		end
		connect(button, function()
			play(get("gender_click_sound"))
			genderSelected()
			send(code)
		end)
	end

	local disconnectGui = get("disconnect_gui")
	if disconnectGui and disconnectGui:IsA("ScreenGui") then disconnectGui.Enabled = false end
	local awakenGui = get("awaken_gui")
	local awakenSerial = 0
	if awakenGui and awakenGui:IsA("ScreenGui") then
		awakenGui.Enabled = true
		for _, item in awakenGui:GetDescendants() do
			if item:IsA("ImageLabel") then item.Visible = false end
		end
	end
	local function showAwaken()
		if not guard() then return end
		awakenSerial += 1
		local serial = awakenSerial
		if awakenGui and awakenGui.Parent then
			awakenGui.Enabled = true
			for _, item in awakenGui:GetDescendants() do
				if item:IsA("ImageLabel") then
					item.Visible = true
					item.ImageTransparency = 0
					TweenService:Create(item, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						ImageTransparency = 1,
					}):Play()
				end
			end
		end
		local colorSource = get("awaken_color")
		if colorSource and colorSource:IsA("ColorCorrectionEffect") then
			local color = colorSource:Clone()
			color.Name = names.transient_visual
			color:SetAttribute(names.runtime_marker, true)
			color.Parent = Lighting
			TweenService:Create(color, TweenInfo.new(0.1), {
				Brightness = 0.5, Contrast = 1, Saturation = 1,
				TintColor = Color3.fromRGB(255, 20, 29),
			}):Play()
			TweenService:Create(color, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.7), {
				Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1),
			}):Play()
			game:GetService("Debris"):AddItem(color, 1.3)
		end
		task.delay(0.55, function()
			if serial ~= awakenSerial or not awakenGui or not awakenGui.Parent then return end
			for _, item in awakenGui:GetDescendants() do
				if item:IsA("ImageLabel") then item.Visible = false end
			end
		end)
	end

	local mobileGui = get("mobile_gui")
	if mobileGui and mobileGui:IsA("ScreenGui") then mobileGui.Enabled = UserInputService.TouchEnabled end
	connect(get("mobile_dash"), function() play(get("mobile_dash") and get("mobile_dash"):FindFirstChildWhichIsA("Sound")); send(49) end)
	connect(get("mobile_getup"), function() play(get("mobile_getup") and get("mobile_getup"):FindFirstChildWhichIsA("Sound")); send(65) end)

	local meter = 0
	local meterBar = get("meter_bar")
	local meterLabel = get("meter_label")
	local meterFlash = get("meter_flash")
	if meterLabel and meterLabel:IsA("TextLabel") then
		meterLabel.Visible = false
		meterLabel.Text = ""
		meterLabel.TextTransparency = 0
	end
	if meterFlash and meterFlash:IsA("ImageLabel") then meterFlash.Visible = false end
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
	if getupPanel and getupPanel:IsA("GuiObject") then getupPanel.Position = UDim2.new(0.5, 0, 1, 50) end
	if getupBar and getupBar:IsA("GuiObject") then getupBar.Size = UDim2.new(0, 0, 1, 0) end
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
		windows.closeAll()
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
		showSubtitle = showSubtitle,
		genderSelected = genderSelected,
		showAwaken = showAwaken,
		setMeter = setMeter,
		phaseFeedback = phaseFeedback,
		recoveryProgress = recoveryProgress,
		beginVote = beginVote,
		updateVotes = updateVotes,
		endVote = endVote,
	}
end

local function wireAdmin(playerGui, player, send, objects, assetIndex, names, guard, windows, allowed)
	local config = assetIndex.admin or {}
	local adminGui = objects[config.gui]
	if not adminGui or not adminGui:IsA("ScreenGui") then return end
	adminGui.Enabled = false
	if not allowed then return end
	adminGui.ResetOnSpawn = false
	adminGui:SetAttribute(names.runtime_marker, true)
	adminGui.Parent = playerGui
	adminGui.Enabled = true

	local function object(key) return objects[config[key]] end
	local function connect(button, callback)
		if button and button:IsA("GuiButton") then
			button.Activated:Connect(function(...)
				if guard() then callback(...) end
			end)
		end
	end
	local window = object("window")
	local profilePage = object("profile_page")
	local commandPage = object("command_page")
	local function closeAdmin()
		if window and window:IsA("GuiObject") and window.Parent then window.Visible = false end
	end
	closeAdmin()
	windows.register("admin", closeAdmin)
	connect(object("open"), function()
		if not window or not window.Parent then return end
		if window.Visible then
			closeAdmin()
		else
			windows.closeAll("admin")
			window.Visible = true
		end
	end)
	connect(object("close_profile"), closeAdmin)
	connect(object("close_command"), closeAdmin)

	local function showProfile()
		if profilePage and profilePage:IsA("GuiObject") then profilePage.Visible = true end
		if commandPage and commandPage:IsA("GuiObject") then commandPage.Visible = false end
	end
	local function showCommands()
		if profilePage and profilePage:IsA("GuiObject") then profilePage.Visible = false end
		if commandPage and commandPage:IsA("GuiObject") then commandPage.Visible = true end
	end
	showProfile()
	for _, id in config.profile_tabs or {} do connect(objects[id], showProfile) end
	for _, id in config.command_tabs or {} do connect(objects[id], showCommands) end

	local function targetBox(index)
		local id = config.target_boxes and config.target_boxes[index]
		local box = id and objects[id]
		return box and box:IsA("TextBox") and box or nil
	end
	local function wireCommands(ids, command)
		for index, id in ids or {} do
			local box = targetBox(index)
			connect(objects[id], function()
				if box then send(161, command, box.Text) end
			end)
		end
	end
	wireCommands(config.kick_buttons, 1)
	wireCommands(config.kill_buttons, 2)
	wireCommands(config.remove_buttons, 3)

	local nameLabel = object("name")
	if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Text = player.Name end
	local dateLabel = object("date")
	if dateLabel and dateLabel:IsA("TextLabel") then dateLabel.Text = os.date("%x") end
	local avatar = object("avatar")
	if avatar and avatar:IsA("ImageLabel") then
		task.spawn(function()
			local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId,
				Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			if ok and guard() and avatar.Parent then avatar.Image = image end
		end)
	end
	local uptime = object("uptime")
	local playerCount = object("players")
	task.spawn(function()
		while guard() and adminGui.Parent do
			local total = math.floor(workspace.DistributedGameTime)
			local hours = math.floor(total / 3600)
			local minutes = math.floor(total / 60) % 60
			local seconds = total % 60
			if uptime and uptime:IsA("TextLabel") then
				uptime.Text = ("Server UpTime: %dh - %dm - %ds"):format(hours, minutes, seconds)
			end
			if playerCount and playerCount:IsA("TextLabel") then
				playerCount.Text = "Players in Server: " .. #Players:GetPlayers()
			end
			task.wait(1)
		end
	end)

	if window and window:IsA("GuiObject") then
		local dragging = false
		local dragStart
		local startPosition
		window.InputBegan:Connect(function(input)
			if not guard() then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPosition = window.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not guard() or not dragging or not dragStart or not startPosition then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				window.Position = UDim2.new(
					startPosition.X.Scale, startPosition.X.Offset + delta.X,
					startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
				)
			end
		end)
	end
end

local function characterVisualBridge(objects, assetIndex, names, guard)
	local source = objects[assetIndex.character_template]
	local partTargets = assetIndex.character_part_targets or {}
	local active = setmetatable({}, {__mode = "k"})
	local partsByCharacter = setmetatable({}, {__mode = "k"})
	local motorsByCharacter = setmetatable({}, {__mode = "k"})
	local function clear(character)
		local visual = active[character]
		if visual and visual.Parent then visual:Destroy() end
		active[character] = nil
		partsByCharacter[character] = nil
		motorsByCharacter[character] = nil
	end
	local function apply(character)
		if not guard() or not character or not character.Parent or not source or not source:IsA("Model") then return end
		clear(character)
		for _, item in character:GetChildren() do
			if item:IsA("BasePart") then item.LocalTransparencyModifier = 1
			elseif item:IsA("Decal") then item.Transparency = 1 end
		end
		local copy
		local owner = Players:GetPlayerFromCharacter(character)
		if owner then
			local ok, avatar = pcall(function()
				local description = Players:GetHumanoidDescriptionFromUserId(owner.UserId)
				return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
			end)
			if ok and avatar and avatar:IsA("Model") then copy = avatar end
		end
		copy = copy or source:Clone()
		copy.Name = names.transient_visual
		copy:SetAttribute(names.runtime_marker, true)
		for _, item in copy:GetDescendants() do
			if item:IsA("Humanoid") or item:IsA("Animator") or item:IsA("Script")
				or item:IsA("LocalScript") then item:Destroy() end
		end
		local proxyRoot = character:FindFirstChild("HumanoidRootPart")
		local sourceRoot
		for _, item in copy:GetDescendants() do
			local targetName = partTargets[item.Name] or item.Name
			if item:IsA("BasePart") and targetName == "HumanoidRootPart" then sourceRoot = item; break end
		end
		if not proxyRoot or not sourceRoot then copy:Destroy(); return end
		local delta = proxyRoot.CFrame * sourceRoot.CFrame:Inverse()
		copy:PivotTo(delta * copy:GetPivot())
		local visualParts = {}
		for _, item in copy:GetDescendants() do
			if item:IsA("BasePart") then
				local targetName = partTargets[item.Name] or item.Name
				item.Anchored = false
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.Massless = true
				if targetName then visualParts[targetName] = item end
			end
		end
		copy.Parent = character
		local rootWeld = Instance.new("WeldConstraint")
		rootWeld.Name = names.transient_visual
		rootWeld:SetAttribute(names.runtime_marker, true)
		rootWeld.Part0 = proxyRoot
		rootWeld.Part1 = sourceRoot
		rootWeld.Parent = sourceRoot
		local visualMotors = {}
		for _, item in copy:GetDescendants() do
			if item:IsA("Motor6D") and item.Part1 then
				local targetName = partTargets[item.Part1.Name] or item.Part1.Name
				if targetName then visualMotors[targetName] = item end
			end
		end
		active[character] = copy
		partsByCharacter[character] = visualParts
		motorsByCharacter[character] = visualMotors
		return copy
	end
	local function setTorsoVisible(character, visible)
		local parts = partsByCharacter[character]
		local torso = parts and (parts.Torso or parts.UpperTorso)
		if torso and torso.Parent then torso.LocalTransparencyModifier = visible and 0 or 1 end
	end
	local function motors(character) return motorsByCharacter[character] end
	local function part(character, targetName)
		local parts = partsByCharacter[character]
		return parts and parts[targetName] or nil
	end
	return {apply = apply, clear = clear, setTorsoVisible = setTorsoVisible, motors = motors, part = part}
end

local function worldWeaponBridge(objects, assetIndex, names, localPlayer, guard, characterVisuals)
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
		local hand = characterVisuals and characterVisuals.part(character, "Right Arm")
			or character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		local copy = source:Clone()
		local handle = copy:FindFirstChild("Handle", true)
		if not hand or not handle or not handle:IsA("BasePart") then copy:Destroy(); return end
		copy.Name = source.Name
		copy:SetAttribute(names.runtime_marker, true)
		copy.RequiresHandle = false
		copy.Parent = character
		for _, item in copy:GetDescendants() do
			if item:IsA("BasePart") then item.CanCollide = false; item.Massless = true
			elseif item:IsA("Trail") then item.Enabled = false end
		end
		handle.CFrame = hand.CFrame
		local joint = Instance.new("Motor6D")
		joint.Name = names.transient_visual
		joint:SetAttribute(names.runtime_marker, true)
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
	local function pulse(owner)
		local record = current[owner]
		local copy = record and record[1]
		if not copy or not copy.Parent then return end
		for _, item in copy:GetDescendants() do
			if item:IsA("Trail") then
				item.Enabled = true
				task.delay(0.5, function() if item.Parent then item.Enabled = false end end)
			end
		end
	end
	return {attach = attach, pulse = pulse}
end

local function morphBridge(objects, assetIndex, names, characterVisuals)
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
		if characterVisuals then characterVisuals.setTorsoVisible(character, true) end
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
		copy:SetAttribute(names.runtime_marker, true)
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
		joint:SetAttribute(names.runtime_marker, true)
		joint.Part0 = torso
		joint.Part1 = anchor
		joint.Parent = torso
		torso.LocalTransparencyModifier = 1
		if characterVisuals then characterVisuals.setTorsoVisible(character, false) end
		active[character] = {copy, joint}
	end
	return apply, clear
end

local function feedbackBridge(playerGui, player, objects, assetIndex, names, guard)
	local refs = assetIndex.feedback or {}
	local decorated = setmetatable({}, {__mode = "k"})
	local hitGui
	local hitCount, hitDamage, hitSerial = 0, 0, 0
	local Debris = game:GetService("Debris")

	local function clonedDescendant(copy, sourceRef)
		local source = objects[sourceRef]
		return source and copy:FindFirstChild(source.Name, true) or nil
	end
	local function markedClone(sourceRef)
		local source = objects[sourceRef]
		if not source then return nil end
		local copy = source:Clone()
		copy.Name = names.transient_visual
		copy:SetAttribute(names.runtime_marker, true)
		return copy
	end
	local function clearDecoration(character)
		local record = decorated[character]
		if not record then return end
		for _, connection in record.connections do connection:Disconnect() end
		if record.gui and record.gui.Parent then record.gui:Destroy() end
		if record.info and record.info.Parent then record.info:Destroy() end
		decorated[character] = nil
	end
	local function decorate(character, owner)
		if not guard() or not character or not character.Parent then return end
		clearDecoration(character)
		local head = character:FindFirstChild("Head")
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		local copy = markedClone(refs.stats)
		local info = markedClone(refs.info)
		if not head or not humanoid or not copy then
			if copy then copy:Destroy() end
			if info then info:Destroy() end
			return
		end
		if copy:IsA("BillboardGui") then copy.Adornee = head end
		copy.Parent = head
		if info then
			if info:IsA("BillboardGui") then info.Adornee = head end
			info.Parent = head
		end
		local nameLabel = clonedDescendant(copy, refs.stats_name)
		local healthBar = clonedDescendant(copy, refs.stats_health)
		local meterBar = clonedDescendant(copy, refs.stats_meter)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = owner and owner.DisplayName or "Player"
		end
		local infoName = info and clonedDescendant(info, refs.info_name)
		local infoNameBackground = info and clonedDescendant(info, refs.info_name_background)
		local genderLabel = info and clonedDescendant(info, refs.info_gender)
		local genderBackground = info and clonedDescendant(info, refs.info_gender_background)
		if infoName and infoName:IsA("TextLabel") then infoName.Text = owner and owner.DisplayName or "Player" end
		if infoNameBackground and infoNameBackground:IsA("TextLabel") then infoNameBackground.Text = owner and owner.DisplayName or "Player" end
		local function updateGender()
			local value = owner and tonumber(owner:GetAttribute(names.state_gender))
			local labels = {[1] = "Female", [2] = "Male", [3] = "Fembxy"}
			local foreground = {[1] = Color3.fromRGB(170, 86, 162), [2] = Color3.fromRGB(27, 175, 158), [3] = Color3.fromRGB(72, 0, 130)}
			local background = value == 1 and Color3.fromRGB(35, 23, 34) or Color3.fromRGB(26, 42, 53)
			if genderLabel and genderLabel:IsA("TextLabel") then
				genderLabel.Text = labels[value] or ""
				if foreground[value] then genderLabel.TextColor3 = foreground[value] end
			end
			if genderBackground and genderBackground:IsA("TextLabel") then
				genderBackground.Text = labels[value] or ""
				genderBackground.TextColor3 = background
			end
		end
		updateGender()
		local function updateHealth(value)
			if healthBar and healthBar:IsA("GuiObject") then
				local ratio = math.clamp(value / math.max(1, humanoid.MaxHealth), 0, 1)
				healthBar.Size = UDim2.new(ratio, 0, healthBar.Size.Y.Scale, healthBar.Size.Y.Offset)
			end
		end
		local function updateMeter()
			if meterBar and meterBar:IsA("GuiObject") then
				local ratio = math.clamp(tonumber(character:GetAttribute(names.state_meter)) or 0, 0, 1)
				meterBar.Size = UDim2.new(ratio, 0, meterBar.Size.Y.Scale, meterBar.Size.Y.Offset)
			end
		end
		updateHealth(humanoid.Health)
		updateMeter()
		local connections = {
			humanoid.HealthChanged:Connect(updateHealth),
			character:GetAttributeChangedSignal(names.state_meter):Connect(updateMeter),
		}
		if owner then connections[#connections + 1] = owner:GetAttributeChangedSignal(names.state_gender):Connect(updateGender) end
		decorated[character] = {gui = copy, info = info, connections = connections}
	end
	local function refreshTags()
		for _, owner in Players:GetPlayers() do
			local character = owner.Character
			if character then
				for _, item in character:GetDescendants() do
					if item:GetAttribute(names.runtime_marker) and item:GetAttribute(names.feedback_tag_marker) then item:Destroy() end
				end
			end
		end
		local leaders = {{names.state_kills, refs.society}, {names.state_nuts, refs.offender}}
		for _, definition in leaders do
			local winner, highest
			for _, owner in Players:GetPlayers() do
				local value = tonumber(owner:GetAttribute(definition[1])) or 0
				if value > 0 and (not highest or value > highest) then winner, highest = owner, value end
			end
			local head = winner and winner.Character and winner.Character:FindFirstChild("Head")
			local tag = head and markedClone(definition[2])
			if tag then
				tag:SetAttribute(names.feedback_tag_marker, true)
				if tag:IsA("BillboardGui") then tag.Adornee = head end
				tag.Parent = head
			end
		end
	end
	local function popup(victim, sourceRef, labelRef, text, color)
		local root = victim and (victim:FindFirstChild("Head") or victim:FindFirstChild("HumanoidRootPart"))
		local copy = root and markedClone(sourceRef)
		if not copy then return end
		if copy:IsA("BillboardGui") then
			copy.Adornee = root
			copy.StudsOffset = Vector3.new(math.random(-12, 12) / 10, 2.8, math.random(-5, 5) / 10)
		end
		local label = clonedDescendant(copy, labelRef)
		if label and label:IsA("TextLabel") then
			label.Text = text
			if color then label.TextColor3 = color end
			local finalSize = label.Size
			label.Size = UDim2.fromScale(0, 0)
			TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Size = finalSize}):Play()
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), {
				TextTransparency = 1, TextStrokeTransparency = 1,
			}):Play()
		end
		copy.Parent = root
		Debris:AddItem(copy, 1.1)
	end
	local function updateHitIndicator(damage)
		hitCount += 1
		hitDamage += damage
		hitSerial += 1
		local serial = hitSerial
		if not hitGui or not hitGui.Parent then
			hitGui = markedClone(refs.hit_gui)
			if hitGui then hitGui.Parent = playerGui end
		end
		if hitGui then
			local countLabel = clonedDescendant(hitGui, refs.hit_count)
			local damageLabel = clonedDescendant(hitGui, refs.hit_damage)
			if countLabel and countLabel:IsA("TextLabel") then countLabel.Text = tostring(hitCount) .. " HITS" end
			if damageLabel and damageLabel:IsA("TextLabel") then damageLabel.Text = tostring(math.floor(hitDamage + 0.5)) end
		end
		task.delay(3, function()
			if serial ~= hitSerial then return end
			if hitGui and hitGui.Parent then hitGui:Destroy() end
			hitGui, hitCount, hitDamage = nil, 0, 0
		end)
	end
	local function impact(attacker, victim, damage, countered)
		damage = tonumber(damage) or 0
		local critical = damage >= 40
		popup(victim, critical and refs.critical or refs.damage,
			critical and refs.critical_label or refs.damage_label,
			"-" .. tostring(math.floor(damage + 0.5)))
		if countered then popup(victim, refs.counter, refs.counter_label, "COUNTER!", Color3.fromRGB(255, 214, 72)) end
		if attacker == player then updateHitIndicator(damage) end
	end
	return {decorate = decorate, impact = impact, refreshTags = refreshTags}
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
	local ok, compatible, gameBuild, protocolVersion, runtimeVersion, assetVersion, adminAllowed = pcall(
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
	for _, name in assetIndex.cleanup_clone_names or {} do cleanupNames[name] = true end
	local cleanupRoots = {playerGui, Lighting, SoundService, workspace}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then cleanupRoots[#cleanupRoots + 1] = backpack end
	for _, service in cleanupRoots do
		local removals = {}
		for _, item in service:GetDescendants() do
			if cleanupNames[item.Name] or item:GetAttribute(names.runtime_marker) then
				removals[#removals + 1] = item
			end
		end
		for index = #removals, 1, -1 do
			local item = removals[index]
			if item:IsA("Sound") then pcall(function() item:Stop() end) end
			pcall(function() item:Destroy() end)
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
	for _, instance in objects do
		if instance:IsA("Sound") then pcall(function() instance:Stop(); instance.TimePosition = 0 end) end
	end
	local characterVisuals = characterVisualBridge(objects, assetIndex, names, guard)
	local animationIndex = module("animations/index.lua")
	local animations = animationPlayer(module, animationIndex, characterVisuals.motors)
	locomotionBridge(animations, names, guard)
	local activeWeather = {}
	local rainConnection
	local function clearWeather()
		if rainConnection then rainConnection:Disconnect(); rainConnection = nil end
		for _, item in activeWeather do if item and item.Parent then item:Destroy() end end
		table.clear(activeWeather)
	end
	local function startRain()
		local config = assetIndex.rain
		if not config then return end
		local anchor = Instance.new("Part")
		anchor.Name = names.transient_visual
		anchor:SetAttribute(names.runtime_marker, true)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Parent = workspace
		local attachment = Instance.new("Attachment")
		attachment.Name = names.transient_visual
		attachment.Parent = anchor
		local drops = Instance.new("ParticleEmitter")
		drops.Name = names.transient_visual
		drops.Texture = config.straight_texture
		drops.Rate = 650 * (config.intensity_ratio or 1)
		drops.Lifetime = NumberRange.new(0.45, 0.7)
		drops.Speed = NumberRange.new(85, 105)
		drops.SpreadAngle = Vector2.new(8, 8)
		drops.EmissionDirection = Enum.NormalId.Bottom
		drops.Orientation = Enum.ParticleOrientation.FacingCamera
		drops.Size = NumberSequence.new(0.16)
		drops.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.8, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		local color = config.color or {0.77, 0.83, 0.87}
		drops.Color = ColorSequence.new(Color3.new(color[1], color[2], color[3]))
		drops.LightInfluence = config.light_influence or 0.9
		drops.LightEmission = config.light_emission or 0
		pcall(function() drops.Squash = NumberSequence.new(4) end)
		drops.Parent = attachment
		local rainSound = Instance.new("Sound")
		rainSound.Name = names.transient_visual
		rainSound:SetAttribute(names.runtime_marker, true)
		rainSound.SoundId = config.sound_id
		rainSound.Volume = config.volume or 0.2
		rainSound.Looped = true
		rainSound.Parent = anchor
		rainSound:Play()
		activeWeather[#activeWeather + 1] = anchor
		rainConnection = RunService.RenderStepped:Connect(function()
			if not guard() or not anchor.Parent then return end
			local camera = workspace.CurrentCamera
			if camera then anchor.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 28, 0)) end
		end)
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
		if weatherCode == 4 then startRain() end
	end
	local musicTemplate = objects[assetIndex.music]
	if musicTemplate and musicTemplate:IsA("Sound") then
		musicTemplate:Stop()
		musicTemplate.TimePosition = 0
		local music = musicTemplate:Clone()
		music.Name = names.transient_visual
		music:SetAttribute(names.runtime_marker, true)
		music.Looped = false
		music:Stop()
		music.TimePosition = 0
		music.Parent = SoundService
		task.spawn(function()
			while music.Parent and guard() do
				if not music.IsPlaying then
					local list = assetIndex.playlist
					if list and #list > 0 then music.SoundId = "rbxassetid://" .. list[math.random(1, #list)] end
					music.TimePosition = 0
					music:Play()
				end
				task.wait(0.25)
			end
			if music.Parent then music:Stop(); music:Destroy() end
		end)
	end
	applyWeather(1)

	local function send(code, ...) actionEvent:FireServer(code, ...) end
	local windows = newWindowController()
	local interface = wireInterface(player, send, objects, assetIndex, names, guard, windows)
	local localTools = wireTools(
		playerGui, player, send, objects, assetIndex, names, guard, interface.attackPreview, windows, characterVisuals
	)
	local worldTools = worldWeaponBridge(objects, assetIndex, names, player, guard, characterVisuals)
	local applyMorph, clearMorph = morphBridge(objects, assetIndex, names, characterVisuals)
	local feedback = feedbackBridge(playerGui, player, objects, assetIndex, names, guard)
	wireAdmin(playerGui, player, send, objects, assetIndex, names, guard, windows, adminAllowed == true)

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
		characterVisuals.apply(character)
		feedback.decorate(character, Players:GetPlayerFromCharacter(character))
		local owner = Players:GetPlayerFromCharacter(character)
		local selection = owner and owner:GetAttribute(names.state_weapon)
		if selection and selection > 0 then
			if owner == player then localTools.equip(selection) else worldTools.attach(owner, selection) end
		end
		decorated[character] = true
		if character == player.Character then
			windows.closeAll()
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
			if owner == player then localTools.equip(selection) else worldTools.attach(owner, selection) end
		end
	end

	actionEvent.OnClientEvent:Connect(function(code, a, b, c, d, e)
		if not guard() then return end
		if code == 129 then
			if b == names.state_weapon then
				if a == player then localTools.equip(c) else worldTools.attach(a, c) end
			end
			if b == names.state_gender and a == player and c ~= nil then interface.genderSelected() end
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
			if b == names.state_kills or b == names.state_nuts or d == names.state_kills or d == names.state_nuts then
				feedback.refreshTags()
			end
		elseif code == 130 then
			local victim, visualCode = b, c
			local root = victim and (victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart"))
			if root then
				cloneVisual(objects, assetIndex.effects[visualCode], root, 5, names.runtime_marker)
				cloneVisual(objects, assetIndex.sounds[visualCode], root, 5, names.runtime_marker)
				local highlight = Instance.new("Highlight")
				highlight.Name = names.transient_visual
				highlight.FillColor = visualCode == 2 and Color3.fromRGB(255, 88, 130) or Color3.new(0, 0, 0)
				highlight.OutlineColor = visualCode == 2 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.45
				highlight.Parent = victim
				game:GetService("Debris"):AddItem(highlight, 0.6)
			end
			animations.play(victim, visualCode == 2 and 13 or (visualCode == 3 and 12 or 11), 1)
			feedback.impact(a, victim, d, e)
		elseif code == 131 then
			animations.play(a, b, c)
		elseif code == 132 then
			local root = a and (a:FindFirstChild("HumanoidRootPart") or a)
			cloneVisual(objects, assetIndex.sounds[b], root, 6, names.runtime_marker)
			if b == 11 then
				local owner = Players:GetPlayerFromCharacter(a)
				if owner == player then localTools.pulse() elseif owner then worldTools.pulse(owner) end
			end
		elseif code == 133 then
			local root = a and (a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("Torso") or a)
			cloneVisual(objects, assetIndex.effects[b], root, 7, names.runtime_marker)
			if b == 8 and a == player.Character then interface.showAwaken() end
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
			interface.showSubtitle(b == 1 and "You can't hide forever." or "...", 3)
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
		elseif code == 148 then
			local commandNames = {[1] = "Kick", [2] = "Kill", [3] = "Remove"}
			if a then
				showNotice(notice, "Admin: " .. (commandNames[b] or "Command") .. " -> " .. tostring(c), 3)
			else
				showNotice(notice, "Admin command failed: target not found or access denied", 4)
			end
		elseif code == 255 then
			showNotice(notice, "Server rejected action " .. tostring(a), 2)
		end
	end)
	send(162)

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
