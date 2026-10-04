local NewChanger = {}

local rs = game:GetService("ReplicatedStorage")
local NewMorphs = rs:WaitForChild("NewMorphs")

function NewChanger:clearMorph(char, name)
	if char:FindFirstChild(name) then
		if char[name]:IsA("Model") then
			char[name]:Destroy()
		end
	end
	if char.HumanoidRootPart:FindFirstChild("Shirt") then
		char.HumanoidRootPart.Shirt.Parent = char
	end
	if char.HumanoidRootPart:FindFirstChild("Pants") then
		char.HumanoidRootPart.Pants.Parent = char
	end
	char.Torso.Transparency = 0
end

local function colorMorph(morph, bodycolor)
	for i,v in pairs(morph:GetDescendants()) do
		if v:IsA("BasePart") then
			if v.Name:find("skin") or v.Name == "LeftTorsoPanel" or v.Name == "RightTorsoPanel" then
				v.Color = bodycolor
			end
		end
	end
end

--function NewChanger.applyAppearance(player, sender)
--	if game.Workspace[player.Name].Status.Value == "downed" then
--		game.Workspace[player.Name].Status.Value = "appearanceApplied"
--		clearMorph(player)
--		local torsoRigClone = MORPHS.TorsoRig:Clone()
--		torsoRigClone.Parent = game.Workspace[player.Name]
--		torsoRigClone.tempPart.CFrame = game.Workspace[player.Name].Torso.CFrame

--		local refWeld = Instance.new("Weld")
--		refWeld.Parent = game.Workspace[player.Name].Torso
--		refWeld.Part0 = game.Workspace[player.Name].Torso
--		refWeld.Part1 = torsoRigClone.tempPart

--		torsoRigClone.tempPart.Transparency = 1
--		game.Workspace[player.Name].Torso.Transparency = 1

--		local bodycolor = game.Workspace[player.Name].Torso.Color

--		colorMorph(torsoRigClone, bodycolor)
		
--		if game.Workspace[player.Name]:FindFirstChild("Shirt") then
--			game.Workspace[player.Name].Shirt:Destroy()
--		end
--		if game.Workspace[player.Name]:FindFirstChild("Pants") then
--			game.Workspace[player.Name].Pants:Destroy()
--		end
--	else
--		print("already appearanceApplied or is not downed!")
--	end
--end

function NewChanger:loadMorph(char, name)
	if NewMorphs:FindFirstChild(name) and char:FindFirstChild("Torso") then
		local morphClone = NewMorphs[name]:Clone()
		morphClone.Parent = char
		colorMorph(morphClone, char.Torso.Color)
		
		local torso = char.Torso
		torso.Transparency = 1
		
		local refWeld = Instance.new("Weld")
		refWeld.Part0 = torso
		refWeld.Part1 = morphClone.ref
		refWeld.Parent = torso
		
		if char:FindFirstChild("Shirt") then
			char.Shirt.Parent = char.HumanoidRootPart
		end
		if char:FindFirstChild("Pants") then
			char.Pants.Parent = char.HumanoidRootPart
		end
		
		for _,v in morphClone.ref.Movables:GetChildren() do
			if v:IsA("Motor6D") then
				v.Part0 = torso
				v.Parent = torso
				for _,p in morphClone.ref.Movables:GetChildren() do
					if p:IsA("BasePart") and p.Name == v.Name then
						v.Part1 = p
					end
				end
			end
		end
	else
		warn("invalid morph or no torso: "..name)
	end
end

return NewChanger
