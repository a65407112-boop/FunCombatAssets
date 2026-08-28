local Hitboxes = {}

Hitboxes.__index = Hitboxes

-- SERVICES
local debris = game:GetService("Debris")
local Remotes = game.ReplicatedStorage.Remotes
local hit = Remotes:WaitForChild("Hit")
local HitCount = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("HitCount"))

function Hitboxes.new(player, move_data)
	local hb = {}
	
	hb.owner_char = player.Character
	hb.ignore_characters = {hb.owner_char}
	
	hb.region = {hb.owner_char.HumanoidRootPart.CFrame * move_data["offset"], move_data["size"]}
	hb.move_data = move_data
	hb.ended = false
	hb.current_state = "startup"
	hb.current_frame = 1

	setmetatable(hb, Hitboxes)
	return hb
end

function Hitboxes:updateFrame()
	if self.ended == false then
		if self.move_data["startup"] <= self.current_frame then
			self.current_state = "active"
		end
		if self.move_data["startup"] + self.move_data["active"] <= self.current_frame then
			self.ended = true
			self.current_state = "recovery"
		end
		self.current_frame += 1
	end
	
	self.region = {self.owner_char.HumanoidRootPart.CFrame * self.move_data["offset"], self.move_data["size"]}
	
	self.ignore_list = self.owner_char:GetDescendants()
	for index,child in pairs(self.ignore_list) do
		if child:IsA("BasePart") == false then
			table.remove(self.ignore_list,index)
		end
	end
	
	return self.ended
end

function Hitboxes:draw()
	local hitbox_ref = Instance.new("Part")
	local hitbox_outline = Instance.new("SelectionBox")
	hitbox_ref.Transparency = 0.95
	hitbox_ref.Material = Enum.Material.SmoothPlastic
	hitbox_ref.Size = self.region[2]
	hitbox_ref.CFrame = self.region[1]
	hitbox_ref.CanCollide = false
	hitbox_ref.Anchored = true
	hitbox_ref.Name = "hitbox_ref"
	hitbox_outline.Adornee = hitbox_ref
	hitbox_outline.LineThickness = 0.03
	hitbox_outline.Parent = hitbox_ref
	if self.current_state == "active" then
		hitbox_outline.Color3 = Color3.fromRGB(0,255,0)
		hitbox_ref.Color = Color3.fromRGB(0,255,0)
	else
		hitbox_outline.Color3 = Color3.fromRGB(255,0,0)
		hitbox_ref.Color = Color3.fromRGB(255,0,0)
	end
	hitbox_ref.Parent = game.Workspace
	debris:AddItem(hitbox_ref, 0.05)
end

function Hitboxes:destroy()
	self.ended = true
end
function Hitboxes:activate()
	if self.current_state == "active" then
		print("activated")
		local collided = workspace:GetPartBoundsInBox(self.region[1], self.region[2])
		
		for _,part in pairs(collided) do
			if table.find(self.ignore_characters, part.Parent) == nil and part.Parent ~= workspace and part.Parent:FindFirstChild("Humanoid") and part.Name ~= "hitbox_ref" and not part.Parent:GetAttribute("iframes") then
				table.insert(self.ignore_characters, part.Parent)
				print(part.Parent)
				hit:FireServer(part.Parent, self.move_data)
				HitCount(self.move_data["damage"])
			end
		end
	end
end

return Hitboxes