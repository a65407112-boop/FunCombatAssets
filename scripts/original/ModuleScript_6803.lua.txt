-- SERVICES --
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")

-- FOLDERS --
local Remotes = RS:WaitForChild("Remotes")

-- MAIN VARIABLES --
local currentTotalDamage = 0
local currentHitCount = 0
local inCD = false

local Player = Players.LocalPlayer

local function FadeOut(gui, value)
	task.delay(3, function()
		if value == currentHitCount then
			gui.Frame:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3, true)
			currentHitCount = 0
			currentTotalDamage = 0
		end
	end)
end

local function round(n)
	return math.floor(n + 0.5)
end

function roundNumber(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

return function(Damage)
	currentHitCount += 1
	currentTotalDamage += Damage
	local spinner
	if not Player.PlayerGui:FindFirstChild("HitIndicator") then
		local hitIndicator = script.HitIndicator:Clone()
		hitIndicator.Parent = Player.PlayerGui
		hitIndicator.Frame.Size = UDim2.fromScale(0,0)
		hitIndicator.Frame:TweenSize(UDim2.fromScale(0.144, 0.272), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.2, true)

		hitIndicator.Frame.Hits.Text = currentHitCount
		hitIndicator.Frame.Hits:TweenSize(UDim2.fromScale(1 * 1.1, 0.33 * 1.1), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
		task.delay(0.06, function()
			if hitIndicator.Frame.Hits.Size == UDim2.fromScale(1 * 1.1, 0.33 * 1.1) then
				hitIndicator.Frame.Hits:TweenSize(UDim2.fromScale(1, 0.33), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
			end
		end)

		hitIndicator.Frame.Damage.Text = roundNumber(currentTotalDamage, 1)

		--spinner = numberSpinner.fromGuiObject(hitIndicator.Frame.Damage)
		--spinner.Prefix = ""
		--spinner.Decimals = 0
		--spinner.Value = currentTotalDamage

		hitIndicator.Frame.Damage:TweenSize(UDim2.fromScale(1 * 1.1, 0.33 * 1.1), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
		task.delay(0.06, function()
			if hitIndicator.Frame.Damage.Size == UDim2.fromScale(1 * 1.1, 0.33 * 1.1) then
				hitIndicator.Frame.Damage:TweenSize(UDim2.fromScale(1, 0.33), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
			end
		end)

		FadeOut(hitIndicator, currentHitCount)
	else
		local hitIndicator = Player.PlayerGui.HitIndicator
		hitIndicator.Frame:TweenSize(UDim2.fromScale(0.144, 0.272), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.2, true)
		hitIndicator.Frame.Hits.Text = roundNumber(currentHitCount,1)
		hitIndicator.Frame.Hits:TweenSize(UDim2.fromScale(1 * 1.1, 0.33 * 1.1), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
		task.delay(0.06, function()
			if hitIndicator.Frame.Hits.Size == UDim2.fromScale(1 * 1.1, 0.33 * 1.1) then
				hitIndicator.Frame.Hits:TweenSize(UDim2.fromScale(1, 0.33), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
			end
		end)

		hitIndicator.Frame.Damage.Text = roundNumber(currentTotalDamage, 1)
		--spinner.Value = currentTotalDamage
		hitIndicator.Frame.Damage:TweenSize(UDim2.fromScale(1 * 1.1, 0.33 * 1.1), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
		task.delay(0.06, function()
			if hitIndicator.Frame.Damage.Size == UDim2.fromScale(1 * 1.1, 0.33 * 1.1) then
				hitIndicator.Frame.Damage:TweenSize(UDim2.fromScale(1, 0.33), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.06, true)
			end
		end)

		FadeOut(hitIndicator, currentHitCount)
	end

end
