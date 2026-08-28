local ts = game:GetService("TweenService")
local setMotor6D = script.Parent:WaitForChild("SetMotor6D")
local DashEvent = script.Parent:WaitForChild("Dash")

local rs = game:GetService("ReplicatedStorage")
local VFX = rs:WaitForChild("VFX")
local dashLimbs = VFX:WaitForChild("dash_limbs")
local dashSmoke = VFX:WaitForChild("dash_smoke")

local CombatFunctions = require(rs:WaitForChild("CombatFunctions"))

setMotor6D.OnServerEvent:Connect(function(plr, t)
	local char = plr.Character
	
	local prevWeld = char:FindFirstChild("Right Arm"):WaitForChild("RightGrip")
	
	if t then
		local newWeld = Instance.new("Motor6D")
		newWeld.Parent = char:FindFirstChild("Right Arm")
		newWeld.Name = "RightGrip"
		newWeld.Part0 = prevWeld.Part0
		newWeld.Part1 = prevWeld.Part1

		newWeld.C0 = prevWeld.C0
		newWeld.C1 = prevWeld.C1
		prevWeld:Destroy()
	else
		prevWeld:Destroy()
	end

end)

DashEvent.OnServerEvent:Connect(function(plr, inAir, awakened)
	local char = plr.Character
	
	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	
	if awakened then
		h.FillColor = Color3.fromRGB(255,0,0)
		h.OutlineColor = Color3.fromRGB(255,0,0)
		CombatFunctions:playSound(script.awakened, char.HumanoidRootPart)
	else
		h.FillColor = Color3.fromRGB(255,255,255)
		h.OutlineColor = Color3.fromRGB(255,255,255)
		CombatFunctions:playSound(script.normal, char.HumanoidRootPart)
	end
	
	h.FillTransparency = 0.7
	h.OutlineTransparency = 0
	h.Parent = char

	local ti = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	local t = ts:Create(h, ti, {OutlineTransparency = 1})
	t:Play()
	game.Debris:AddItem(h, 0.4)
	
	local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
	local enabled_trails = {}
	for _,l in limbs do
		-- random ahh check
		if char[l]:FindFirstChild("dash0") then
			for _,thing in char[l]:GetChildren() do
				if thing:IsA("Trail") and string.find(thing.Name, "dash") then
					thing.Enabled = true
					table.insert(enabled_trails, thing)
				end
			end
		else
			local dash_vfx = dashLimbs:Clone():GetChildren()
			for _,p in dash_vfx do
				p.Parent = char[l]
				if p:IsA("Trail") then
					p.Enabled = true
					table.insert(enabled_trails, p)
				end
			end
		end
	end

	task.spawn(function()
		task.wait(0.3)
		for _,e in enabled_trails do
			e.Enabled = false
		end
	end)

	if not inAir then
		if not char.PrimaryPart:FindFirstChild("dust") then
			local smoke = dashSmoke.dust:Clone()
			smoke.Parent = char.PrimaryPart
		end
		for _,part in char.PrimaryPart.dust:GetChildren() do
			part.Enabled = true
		end
		task.spawn(function()
			task.wait(0.3)
			for _,part in char.PrimaryPart.dust:GetChildren() do
				part.Enabled = false
			end
		end)
	end
end)