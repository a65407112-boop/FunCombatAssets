-- FunCombat / Null Protocol native RBXM client loader v2
-- Gameplay remains server-authoritative. This file only restores presentation,
-- client input, and server-broadcast visuals from native RBXM assets.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G
local unpackf = table.unpack or unpack

if ENV.__FUNCOMBAT_RUNTIME and type(ENV.__FUNCOMBAT_RUNTIME.destroy)=="function" then
    pcall(ENV.__FUNCOMBAT_RUNTIME.destroy)
end

local runtime={connections={},imported={},dead=false,localFound=0,localStarted=0,localUnreadable=0,localFailed=0}
ENV.__FUNCOMBAT_RUNTIME=runtime

local function connect(signal,fn)
    local c=signal:Connect(fn)
    table.insert(runtime.connections,c)
    return c
end
local function track(v)
    if v then table.insert(runtime.imported,v) end
    return v
end
function runtime.destroy()
    if runtime.dead then return end
    runtime.dead=true
    for _,c in ipairs(runtime.connections) do pcall(function()c:Disconnect()end) end
    for _,v in ipairs(runtime.imported) do pcall(function()if v and v.Parent then v:Destroy() end end) end
    local g=pg:FindFirstChild("__FunCombatLoader")
    if g then pcall(function()g:Destroy()end) end
end

local statusGui=Instance.new("ScreenGui")
statusGui.Name="__FunCombatLoader"
statusGui.ResetOnSpawn=false
statusGui.IgnoreGuiInset=true
statusGui.DisplayOrder=1000000
statusGui.Parent=pg
track(statusGui)
local statusLabel=Instance.new("TextLabel")
statusLabel.AnchorPoint=Vector2.new(.5,0)
statusLabel.Position=UDim2.new(.5,0,0,8)
statusLabel.Size=UDim2.new(0,850,0,42)
statusLabel.BackgroundColor3=Color3.fromRGB(18,18,22)
statusLabel.BackgroundTransparency=.08
statusLabel.TextColor3=Color3.new(1,1,1)
statusLabel.Font=Enum.Font.Code
statusLabel.TextSize=15
statusLabel.TextWrapped=true
statusLabel.Text="FunCombat client v2: starting"
statusLabel.Parent=statusGui
local function status(s,bad)
    print("[FunCombat client v2] "..tostring(s))
    statusLabel.Text="FunCombat client v2: "..tostring(s)
    statusLabel.BackgroundColor3=bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,65,34)
end

-- The published place keeps networking names opaque. Restore only this client's
-- view so the original presentation scripts can use their old clear paths.
local ALIAS={
    xaf2bb0d97d5d="Remotes", x4ebfd059b5e5="Hit", x40d6f4553ed6="PlaySound",
    x1fe87e6f17e8="ToggleParticles", xdc7fa05180f4="RagdollPlayer", x55e99a4dbb9d="Flash",
    x0d62dfb56e92="OnDeath", xc7720e51b46a="Ragdoll", x628ca2667e5d="RagdollForce",
    xe40a2326dbcf="TestAnimation", xad6326c1f61a="ChangeFunSpeed", xda7da817ec4a="ShowPrompt",
    x6b53699e19c1="IncreaseHitCount", x2a8e35ff91f9="ToggleResetting", xbb075d6bde39="DamageIndicator",
    x3050ec664e12="GetUp", xc013ac8c95d3="WallBounce", x2b267bb2c88a="Subtitles",
    x5988a13e5f9e="Emote", x1f40555480ee="ChangeAttacking", x1aed02c56da9="AwakenScreen",
    x8b438ed476b7="EquipWeapon",
    x06f340810381="RemoteEvents", xb53505bd95ca="Voted", x29bf1a4c4c94="VotingBegun",
    xe29bc60e6ec8="VotingEnded", x321747c0f450="awakenEvent", xede98b410a21="chatEvent",
    x4fbe0e9e0c97="weatherEvent", xbe2a334db2dd="UIRemote",
    x38e8915cf6c4="Prompts", xb085b6cb9c31="executePrompt", x569e44ba87ee="DefaultFun",
    xa5e54555633d="stopPrompt", xcaa35f67af02="carryPrompt", xc9eca057a6dd="dropPrompt",
    x90b04380a978="finishHoldPrompt", x3af6217d1a92="AttributeSystem", x967d386c24d6="SetInfo",
}
local function fixPrompt(v)
    if not v:IsA("ProximityPrompt") then return end
    if v.Name=="executePrompt" then v.ActionText="Execute";v.ObjectText="Victim"
    elseif v.Name=="carryPrompt" then v.ActionText="Carry";v.ObjectText="Victim"
    elseif v.Name=="DefaultFun" then v.ActionText="Fun";v.ObjectText="Victim"
    elseif v.Name=="dropPrompt" then v.ActionText="Drop"
    elseif v.Name=="stopPrompt" then v.ActionText="Stop"
    elseif v.Name=="finishHoldPrompt" then v.ActionText="Finish" end
end
local function translate(v)
    local n=ALIAS[v.Name]
    if n then pcall(function()v.Name=n end) end
    fixPrompt(v)
end
for _,v in ipairs(RS:GetDescendants()) do translate(v) end
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then translate(v) end end
connect(workspace.DescendantAdded,function(v) task.defer(translate,v) end)

local remotes=RS:WaitForChild("Remotes",15)
local remoteEvents=RS:WaitForChild("RemoteEvents",15)
local attrSystem=RS:WaitForChild("AttributeSystem",15)
if not remotes then error("server Remotes missing; publish the FIXED server-only RBXL") end
if not attrSystem or not attrSystem:FindFirstChild("SetInfo") then error("server AttributeSystem/SetInfo missing") end

-- ---------------------------------------------------------------------------
-- Native RBXM import. Xeno's LoadLocalAsset returns only one root. Four client
-- packs contain multiple top-level roots, so we wrap them inside one Folder at
-- the binary PRNT level before calling GetObjects, then unwrap after import.
-- ---------------------------------------------------------------------------
