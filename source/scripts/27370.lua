for _,v in script.Parent:GetChildren() do
	if v:IsA("BasePart") then
		v.Touched:Connect(function(part)
			if part.Parent:FindFirstChild("Humanoid") then
				local player = game:GetService("Players"):GetPlayerFromCharacter(part.Parent)
				if part.Parent.Humanoid.Health > 0 then
					part.Parent:SetAttribute("iframes", false)
					part.Parent:SetAttribute("downed", false) 
					part.Parent.Humanoid.Health = 0
					
					local s = script:WaitForChild("Sound"):Clone()
					s.Parent = part
					s:Play()					
					task.wait(2) 
					player:LoadCharacter()
				end
			end
		end)
	end
end