--Made by Luckymaxer

Mouse_Icon = "rbxasset://textures/GunCursor.png"
Reloading_Icon = "rbxasset://textures/GunWaitCursor.png"

Tool = script.Parent

local char = game.Workspace:WaitForChild(game.Players.LocalPlayer.Name)
local hum = char:WaitForChild("Humanoid")
local root = char.HumanoidRootPart

local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local flourish_anim = rs.Animations.bat.flourish
local unequip = rs.Animations.bat.unequip

local m1_count = 1

local currentPlaying
localAnimationPlayer = game:GetService("ReplicatedStorage").AnimationManager.LocalScriptAPI

local Hitboxes = require(script:WaitForChild("Hitboxes"))
local MoveData = require(rs:WaitForChild("MoveData"))
local CombatFunctions = require(rs:WaitForChild("CombatFunctions"))

local Rate = 1 / 60 -- 10 times a second
local swing_debounce = true
local dash_debounce = false
local Accumulated = 0
local RunService = game:GetService"RunService"
local Heartbeat = RunService.Heartbeat

local rs = game:GetService("ReplicatedStorage")
local Remotes = rs:WaitForChild("Remotes")
local PlaySound = Remotes:WaitForChild("PlaySound")
local DashEvent = script.Parent:WaitForChild("Dash")
local ToggleParticles = Remotes:WaitForChild("ToggleParticles")
local Flash = Remotes:WaitForChild("Flash")
local ChangeAttacking = Remotes:WaitForChild("ChangeAttacking")

local Toggle = game.Players.LocalPlayer.PlayerGui.HitboxToggle:WaitForChild("Toggle")

hitbox_list = {}

local setMotor6D = Tool:WaitForChild("SetMotor6D")

local swingSound = Tool.Handle:WaitForChild("Swing")
local equip = Tool.Handle:WaitForChild("Equip")
local equip2 = Tool.Handle:WaitForChild("Equip2")
local unequipSound = Tool.Handle:WaitForChild("Unequip")

local inputConnection
local mobileDashConnection

local mobileButtons = game.Players.LocalPlayer.PlayerGui:WaitForChild("mobileButtons")
local DashButton = mobileButtons.Dash

local prevAttacking = false

Heartbeat:Connect(function(DeltaTime)
	Accumulated += DeltaTime
	while Accumulated >= Rate do
		Accumulated -= Rate
		local canAttack = true
		if char:FindFirstChild("stun") then
			if char.stun:IsA("BoolValue") then
				canAttack = false
			end
		end
		if char:FindFirstChild("carrying") then
			if char.carrying:IsA("BoolValue") then
				canAttack = false
			end
		end
		if char:GetAttribute("downed") == true then
			canAttack = false
		end
		if canAttack then
			for _,hitbox in pairs(hitbox_list) do
				local check = hitbox:updateFrame()
				hitbox:activate()
				if Toggle.Value then
					hitbox:draw()
				end
				if check == true then
					table.remove(hitbox_list, table.find(hitbox_list, hitbox))
				end
			end
			if #hitbox_list > 0 then
				if not prevAttacking then
					prevAttacking = true
					ChangeAttacking:FireServer(true)
				end
			else
				if prevAttacking then
					prevAttacking = false
					ChangeAttacking:FireServer(false)
				end
			end
		else
			if prevAttacking then
				prevAttacking = false
				ChangeAttacking:FireServer(false)
			end
			hitbox_list = {}
		end
	end
end)

Mouse = nil

function UpdateIcon()
	if Mouse then
		Mouse.Icon = Tool.Enabled and Mouse_Icon or Reloading_Icon
	end
end

function Swing()
	if char:FindFirstChild("stun") then
		if char.stun:IsA("BoolValue") then
			warn("is stunned - cannot attack")
			return
		end
	end
	if char:FindFirstChild("carrying") then
		if char.carrying:IsA("BoolValue") then
			warn("is carrying - cannot attack")
			return
		end
	end
	if char:GetAttribute("downed") == true then
		return 
	end
	if swing_debounce == false then
		swing_debounce = true
		localAnimationPlayer.PlayAnimation:InvokeServer(rs.Animations.bat["swing_"..m1_count], game.Players.LocalPlayer.Character)
		
		if m1_count ~= 3 then
			table.insert(hitbox_list, Hitboxes.new(game.Players.LocalPlayer, MoveData.get_data("SWING_"..m1_count)))
			PlaySound:FireServer(swingSound, nil, nil, ((math.random(-50, 50) * 0.01) + 1))
			ToggleParticles:FireServer(Tool.Handle.Trail, true, 0.5)
			m1_count += 1
		else
			table.insert(hitbox_list, Hitboxes.new(game.Players.LocalPlayer, MoveData.get_data("BIG_SWING")))
			Flash:FireServer(Color3.fromRGB(227, 219, 219), Color3.fromRGB(0, 0, 0), 0.4)
			wait(0.7)
			PlaySound:FireServer(swingSound, nil, nil, ((math.random(-50, 50) * 0.01) + 1))
			ToggleParticles:FireServer(Tool.Handle.Trail, true, 0.5)
			m1_count = 1
		end
		
		wait(0.4)
		swing_debounce = false
	end
end

function Dash()
	if char:FindFirstChild("stun") then
		if char.stun:IsA("BoolValue") then
			warn("is stunned - cannot dash")
			return
		end
	end
	if char:FindFirstChild("carrying") then
		if char.carrying:IsA("BoolValue") then
			warn("is carrying - cannot dash")
			return
		end
	end
	if char:GetAttribute("downed") == true then
		return 
	end
	if dash_debounce == false  then
		dash_debounce = true

		PlaySound:FireServer(script.Parent.Handle:FindFirstChild("DashSound"), nil, nil)
		hum.JumpPower = 0
		
		local DASH_DISTANCE = 18
		
		if char:GetAttribute("awakened") then
			DASH_DISTANCE = 25
		else
			DASH_DISTANCE = 18
		end
		
		--if hum.FloorMaterial ~= Enum.Material.Air then
		--	ReplicationEvent:FireServer("Dash", true)
		--else
		--	ReplicationEvent:FireServer("Dash", false)
		--end

		--local DASH_DISTANCE = nil
		--if Items.GetItemInfo(DataDirectory[plr.Name].Style.Value, "DashDistance") == nil then
		--	print("default dash")
		--	DASH_DISTANCE = Items.GetItemInfo("Combat", "DashDistance")
		--else
		--	DASH_DISTANCE = Items.GetItemInfo(DataDirectory[plr.Name].Style.Value, "DashDistance")
		--	if DataDirectory[plr.Name].Style.Value == "Rush" then
		--		AttackEvent:FireServer("SkillRep", "Rush", "Dash")
		--	end
		--end
		
		if hum.FloorMaterial == Enum.Material.Air then
			DashEvent:FireServer(true, char:GetAttribute("awakened"))
		else
			DashEvent:FireServer(false, char:GetAttribute("awakened"))
		end

		local dir_cframe 
		local velocity = root.CFrame:Inverse() * (root.Position + root.Velocity)
		local yDirection = math.atan2(velocity.X, -velocity.Z)
		local roundedDirection = math.ceil(math.deg(yDirection) - 0.5)	

		if (roundedDirection <= -135 or roundedDirection >= 135) then
			-- DASH BACK
			dir_cframe = CFrame.new(0,0,DASH_DISTANCE)
		elseif roundedDirection < -45 and roundedDirection > -135 then
			-- DASH LEFT
			dir_cframe = CFrame.new(-DASH_DISTANCE,0,0)
		elseif roundedDirection > 45 and roundedDirection < 135 then
			-- DASH RIGHT
			dir_cframe = CFrame.new(DASH_DISTANCE,0,0)
		elseif roundedDirection <= 45 and roundedDirection >= -45 then
			-- DASH FORWARD
			dir_cframe = CFrame.new(0,0,-DASH_DISTANCE)
		end

		wait(0.15)
		
		CombatFunctions:pull(root, dir_cframe, 0.3, 30000, 30, "dash_part")
		
		wait(0.7)

		hum.JumpPower = 50
		
		wait(0.5)
		
		dash_debounce = false
	end
end

function OnEquipped(ToolMouse)
	swing_debounce = true
	Mouse = ToolMouse
	UpdateIcon()
	setMotor6D:FireServer(true)
	PlaySound:FireServer(equip, nil, nil)
	localAnimationPlayer.PlayAnimation:InvokeServer(flourish_anim, game.Players.LocalPlayer.Character)
	wait(1.5)
	PlaySound:FireServer(equip2, nil, nil)
	wait(0.25)
	
	swing_debounce = false

	inputConnection = uis.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Q then
			Dash()
		end
	end)
	
	mobileDashConnection = DashButton.Activated:Connect(function(input, clickNumber)
		Dash()
	end)
	--local prevWeld = char:FindFirstChild("Right Arm"):WaitForChild("RightGrip")
	--local newWeld = Instance.new("Motor6D")
	--newWeld.Parent = char:FindFirstChild("Right Arm")
	--newWeld.Name = "RightGrip"
	--newWeld.Part0 = prevWeld.Part0
	--newWeld.Part1 = prevWeld.Part1

	--newWeld.C0 = prevWeld.C0
	--newWeld.C1 = prevWeld.C1
	--prevWeld:Destroy()
end


function OnChanged(Property)
	if Property == "Enabled" then
		UpdateIcon()
	end
end

function onUnequip()
	if inputConnection then
		inputConnection:Disconnect()
	end
	if mobileDashConnection then
		mobileDashConnection:Disconnect()
	end
	
	prevAttacking = false
	ChangeAttacking:FireServer(false)
	
	localAnimationPlayer.PlayAnimation:InvokeServer(unequip, game.Players.LocalPlayer.Character)
	PlaySound:FireServer(unequipSound)
	setMotor6D:FireServer(false)
end

Tool.Equipped:Connect(OnEquipped)
Tool.Changed:Connect(OnChanged)
Tool.Activated:Connect(Swing)
Tool.Unequipped:Connect(onUnequip)

