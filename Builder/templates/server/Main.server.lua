-- Combat is adapted here; the original Kohl dependency keeps its native settings.
local Config=require(script.Parent.Config)
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local net=assert(RS:FindFirstChild(Config.names[1]),"Encoded protocol folder is missing")
assert(net:FindFirstChild(Config.names[5]).Value==Config.version,"Protocol version mismatch")
assert(net:FindFirstChild(Config.names[6]).Value==Config.buildId,"Protocol build mismatch")
assert(not net:GetAttribute("Started"),"Duplicate FunCombat server startup")
net:SetAttribute("Started",true)
local templates=assert(SS:FindFirstChild("FunCombatData"),"Source dependencies are missing")
local Combat=require(script.Parent.CombatServer)
local World=require(script.Parent.World)
local Voting=require(script.Parent.Voting)
local AdminAccess=require(script.Parent.AdminAccess)
local KohlAdmin=require(script.Parent.KohlAdmin)
local combat=Combat.new({folder=net,config=Config},templates)
combat.adminAccess=AdminAccess.new(function(player,allowed,status)
    combat.snapshotGates[player]=nil
    combat:emit("Admin",{allowed=allowed,creator=status},player)
    if allowed then print("FunCombat admin access granted: userId="..player.UserId.."; source="..tostring(player:GetAttribute("FunCombatAdminSource"))) end
end,10,Config.ownerUserId)
local world=World.new(combat,templates)
local voting=Voting.new(combat,world,templates.Maps)
world:start();combat:start();voting:start()
combat.kohl=KohlAdmin.start(game:GetService("ServerScriptService"):FindFirstChild("Kohl's Admin Infinite"),combat.adminAccess,world,20,function(status)
    for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
        combat.snapshotGates[player]=nil
        local admin=combat:adminState(player);admin.kohl=status
        combat:emit("Admin",admin,player)
    end
    if status.state=="ready" then print("FunCombat original Kohl's Admin ready; asset "..status.assetId) end
end)
print("FunCombat server ready; protocol "..Config.version..", build "..Config.buildId)
