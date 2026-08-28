local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
local Remotes = rs:WaitForChild("Remotes")
local IncreaseHitCount = Remotes:WaitForChild("IncreaseHitCount")

local HitCount = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("HitCount"))
local DamageIndicator = Remotes:WaitForChild("DamageIndicator")
local random = Random.new()

local camera = game.Workspace.CurrentCamera

local c = require(script.Parent:WaitForChild("CameraShaker"))
local CameraShaker = c.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	camera.CFrame = camera.CFrame * shakeCFrame
end)

local CamShake = Remotes:WaitForChild("CamShake")

-- mobile

warn("HELLO")

uis.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		warn("IS MOBILE")
		plr.PlayerGui.mobileButtons.Enabled = true
	end
end)

--[[
if uis.TouchEnabled and not uis.KeyboardEnabled and not uis.MouseEnabled then
	warn("IS MOBILE")
	plr.StarterGui.mobileButtons.Enabled = true
end
]]--

IncreaseHitCount.OnClientEvent:Connect(function(damage)
	--warn("FROM HIT COUNT")
	if damage then
		HitCount(damage)
	else
		HitCount(0)
	end
end)

-- back to normal
for i,v in pairs(game.Workspace:GetChildren()) do
	if v:FindFirstChild("IsMap") then
		DamageIndicator.OnClientEvent:Connect(function(damage, character, counter)
			-- DAMAGE INDICATOR GUI --
			local gui
			if damage >= 40 then
				gui = script:WaitForChild("DamageIndicatorCrit"):Clone()
			else
				gui = script:WaitForChild("DamageIndicator"):Clone()
			end

			gui.Damage.Size = UDim2.fromScale(0,0)
			gui.Damage.TextColor3 = Color3.fromRGB(255, 255, 255) -- TEXT COLOR
			gui.StudsOffset = Vector3.new(random:NextNumber(-1.5, 1.5), random:NextNumber(-1, 1), random:NextNumber(-0.5, 0.5)) -- RANDOM POS
			--gui.Damage.Text = tostring(RoundNumber(Damage))
			gui.Damage.Text = tostring(damage)
			gui.Parent = game.Workspace.Debris -- we just gotta make a loop or some shi bc the script isnt updating the map, but the map is changing
			gui.Adornee = character.HumanoidRootPart

			-- TWEENS --
			gui.Damage:TweenSize(UDim2.fromScale(0.9, 0.9), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1, true)
			task.delay(0.1, function()
				gui.Damage:TweenSize(UDim2.fromScale(0.75, 0.75), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
				task.delay(0.75, function()
					gui.Damage:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.2, true)
					game.Debris:AddItem(gui, 0.2)
				end)
			end)

			if counter then
				local gui
				gui = script:WaitForChild("CounterIndicator"):Clone()

				gui.Damage.Size = UDim2.fromScale(0,0)
				gui.Damage.TextColor3 = Color3.fromRGB(255, 255, 255) -- TEXT COLOR
				gui.StudsOffset = Vector3.new(random:NextNumber(-1.5, 1.5), random:NextNumber(-1, 1), random:NextNumber(-0.5, 0.5)) -- RANDOM POS
				--gui.Damage.Text = tostring(RoundNumber(Damage))
				gui.Parent = v.Debris
				gui.Adornee = character.HumanoidRootPart

				-- TWEENS --
				gui.Damage:TweenSize(UDim2.fromScale(0.9, 0.9), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1, true)
				task.delay(0.1, function()
					gui.Damage:TweenSize(UDim2.fromScale(0.75, 0.75), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
					task.delay(0.75, function()
						gui.Damage:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.2, true)
						game.Debris:AddItem(gui, 0.2)
					end)
				end)
			end
		end)
	end
end


CamShake.OnClientEvent:Connect(function(tag)
	CameraShaker:Shake(CameraShaker.Presets[tag])
end)