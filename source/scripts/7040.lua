local debrisService = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local enabledButton = nil
local replicatedStorage = game:GetService("ReplicatedStorage")
local setInfoEvent = replicatedStorage.AttributeSystem.SetInfo
local players = game:GetService("Players")
local player = players.LocalPlayer

for _, button in pairs(script.Parent:GetChildren()) do
	if not button:IsA("TextButton") then continue end
	
	
	
	button.MouseEnter:Connect(function()
		local hoverSoundClone = script.Hover:Clone()
		hoverSoundClone.Parent = workspace.CurrentCamera
		hoverSoundClone:Play()
		debrisService:AddItem(hoverSoundClone, hoverSoundClone.TimeLength)

		if tonumber(button.Name) then
			tweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				BackgroundColor3 = Color3.fromRGB(72, 0, 130)
			}):Play()
		end

		if button.Name ~= "Close" then
			tweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				Rotation = -3
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		if tonumber(button.Name) and enabledButton ~= button then
			tweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				BackgroundColor3 = Color3.fromRGB(72, 0, 130)
			}):Play()
		end

		if button.Name ~= "Close" and enabledButton ~= button then
			tweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				Rotation = 0
			}):Play()
		end
	end)

	button.MouseButton1Click:Connect(function()
		
		local clickSoundClone = script.Click:Clone()
		clickSoundClone.Parent = workspace.CurrentCamera
		clickSoundClone:Play()
		debrisService:AddItem(clickSoundClone, clickSoundClone.TimeLength)

		if not tonumber(button.Name) then 
			setInfoEvent:FireServer("Gender", button.Text)
		end
		
		wait(.1) -- allow properties to be set, task.defer is too fast.
		
		if player:GetAttribute("Gender") then
			script.Parent.Parent.Enabled = false 
			--player.PlayerGui:WaitForChild("main").Enabled = true
			
		end
	end)
end