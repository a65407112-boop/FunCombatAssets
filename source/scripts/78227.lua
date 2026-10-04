local Remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local Hit = Remotes:WaitForChild("Hit")
local RagdollPlayer = Remotes:WaitForChild("RagdollPlayer")

local rs = game:GetService("ReplicatedStorage")
local HitVFX = rs:WaitForChild("VFX"):WaitForChild("Hits")
local downed_anim = rs.Animations.other.downed

local Sounds = rs:WaitForChild("Sounds")

local currentPlaying
local Animator = require(rs.AnimationManager)

local RagdollModule = require(rs:WaitForChild("Manager"))
local CombatFunctions = require(rs:WaitForChild("CombatFunctions"))
local animator = require(rs.AnimationManager)

Hit.OnServerEvent:Connect(function(player, victim, move_data)
	
	CombatFunctions:hit(player, victim, move_data)
	--local hitSound = Sounds:FindFirstChild(move_data["vfx"])
	--if hitSound then
	--	local newSound = hitSound:Clone()
	--	newSound.Parent = victim.HumanoidRootPart
	--	newSound:Play()
	--	game.Debris:AddItem(newSound, newSound.TimeLength + 1)
	--else
	--	warn("invalid hit sound: "..move_data["vfx"])
	--end
	
	--print(victim)
	
	--local deduction = victim.Humanoid.Health - move_data["damage"]
	--if deduction <= 0 then
	--	-- victim.HumanoidRootPart.Anchored = true
	--	-- Animator.PlayAnimation(downed_anim, victim)
		
	--	if game.Players:FindFirstChild(victim.Name) then
	--		print("is a player")
	--	else
	--		print("not a player")
	--	end
		
	--	warn("ragdolled "..victim.Name)
	--	RagdollModule.Ragdoll(victim)
	--	victim:SetAttribute("downed", true)
	--	if victim.Torso:FindFirstChild("executePrompt") then
	--		victim.Torso.executePrompt.Enabled = true
	--	end
		
	--	warn("downed "..victim.Name)
	--else
	--	victim.Humanoid:TakeDamage(move_data["damage"])
	--	warn("took ", move_data["damage"], "damage.")
	--end
	
	--if rs.Animations.bat:FindFirstChild(move_data["stun_anim"]) then
	--	animator.PlayAnimation(rs.Animations.bat[move_data["stun_anim"]], victim)
	--else
	--	warn("invalid hit anim: "..move_data["stun_anim"])
	--end
	
	--CombatFunctions:newStun(victim, move_data["stun"])
	
	--if not victim:GetAttribute("downed") and move_data["ragdoll"] then
	--	RagdollModule.Ragdoll(victim)
	--	task.spawn(function()
	--		wait(move_data["ragdoll"])
	--		if victim then
	--			warn("unragdolled "..victim.Name)
	--			RagdollModule.UnRagdoll(victim)
	--		end
	--	end)
	--end


	--local KnockBack = Instance.new("BodyVelocity")
	--KnockBack.Parent = victim.HumanoidRootPart--part is the target of the knockback/ the opponent
	--KnockBack.MaxForce = Vector3.new(move_data["kb_force"],move_data["kb_force"],move_data["kb_force"])
	--KnockBack.Velocity = player.Character.PrimaryPart.CFrame.LookVector * move_data["kb_speed"] -- based on the direction YOUR character is facing
	--game.Debris:AddItem(KnockBack, move_data["kb_duration"])
	
	--local vfxDest
	--if victim:FindFirstChild("Torso") then
	--	vfxDest = victim.Torso
	--else
	--	vfxDest = victim.HumanoidRootPart
	--end
	
	--if vfxDest:FindFirstChild(move_data["vfx"]) then
	--	if vfxDest:FindFirstChild(move_data["vfx"]):IsA("Attachment") then
	--		for _,p in vfxDest:FindFirstChild(move_data["vfx"]):GetChildren() do
	--			p:Emit(p:GetAttribute("EmitCount"))
	--		end
	--		return
	--	end
	--end
	
	--if HitVFX:FindFirstChild(move_data["vfx"]) then
	--	local vfxClone = HitVFX[move_data["vfx"]]:Clone()
	--	vfxClone.Parent = vfxDest
	--	for _,p in vfxClone:GetChildren() do
	--		p:Emit(p:GetAttribute("EmitCount"))
	--	end
	--else
	--	warn("invalid vfx attachment: " + move_data["vfx"])
	--end
end)

