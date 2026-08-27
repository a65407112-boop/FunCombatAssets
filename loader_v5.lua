-- Null Protocol runtime v5
-- v4 keeps the client reconstruction/event-driven asset loading.
-- v5 fixes presentation of the server's invisible R6 proxy without cloning a shell.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ENV = (getgenv and getgenv()) or _G

local V4 = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/7ae7fda612a2b8b88dc17d43ef1d528a2d01fdb3/loader_fixed.lua"
local src = game:HttpGet(V4 .. "?cb=" .. tostring(os.clock()))
local fn, err = loadstring(src, "NullProtocolV4Base")
if not fn then error("Null Protocol v5: v4 base compile failed: " .. tostring(err)) end
local result = fn()

-- The server intentionally keeps its gameplay rig invisible. Do not create a
-- second physical/shell rig. Reveal the existing R6 parts locally instead.
local BODY = {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg","HumanoidRootPart"}
local function setBaseVisible(char, visible)
    if not char or not char.Parent then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.RigType ~= Enum.HumanoidRigType.R6 then
        warn("[Null Protocol] expected R6 proxy, got " .. tostring(hum.RigType))
        return
    end

    local tr = visible and 0 or 1
    for _, name in ipairs(BODY) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            pcall(function() part.Transparency = tr end)
            pcall(function() part.LocalTransparencyModifier = 0 end)
            for _, d in ipairs(part:GetDescendants()) do
                if d:IsA("Decal") then pcall(function() d.Transparency = tr end) end
            end
        end
    end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local h = v:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then pcall(function() h.Transparency = tr end) end
        elseif visible and v:IsA("CharacterMesh") then
            -- The intended starting body is classic Blocky R6.
            pcall(function() v:Destroy() end)
        end
    end
end
ENV.__NULL_SET_BASE_VISIBLE = setBaseVisible

-- Server applies the description/hides proxy parts about a second after spawn,
-- so reveal after that write has arrived. Also reveal immediately for late runtime starts.
local function watchCharacter(char)
    task.defer(function() setBaseVisible(char, true) end)
    task.delay(1.35, function()
        if char and char.Parent then setBaseVisible(char, true) end
    end)
end
local function watchPlayer(p)
    if p.Character then watchCharacter(p.Character) end
    p.CharacterAdded:Connect(watchCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- Morph visibility is entirely server-driven. M+ hides the base blocky proxy;
-- M- restores it. The v4 core separately lazy-loads rig_assets only on M+.
task.spawn(function()
    local remotes = RS:WaitForChild("Remotes", 15)
    local bus = remotes and remotes:WaitForChild("TestAnimation", 15)
    if not bus or not bus:IsA("RemoteEvent") then
        warn("[Null Protocol] visual bus missing; base R6 will remain visible")
        return
    end
    bus.OnClientEvent:Connect(function(op, ...)
        local a = {...}
        if op == "M+" then
            setBaseVisible(a[1], false)
        elseif op == "M-" then
            task.defer(function() setBaseVisible(a[1], true) end)
        end
    end)
end)

-- Network audit. These must be real server-replicated remotes, not reconstructed
-- presentation objects. Missing entries mean the published server build is wrong.
task.defer(function()
    local checks = {
        {"AttributeSystem","SetInfo"},
        {"Remotes","Hit"}, {"Remotes","GetUp"}, {"Remotes","Emote"},
        {"Remotes","ChangeFunSpeed"}, {"Remotes","TestAnimation"},
        {"RemoteEvents","Voted"}, {"RemoteEvents","VotingBegun"}, {"RemoteEvents","VotingEnded"},
    }
    local missing = {}
    for _, pair in ipairs(checks) do
        local folder = RS:FindFirstChild(pair[1])
        local obj = folder and folder:FindFirstChild(pair[2])
        if not obj then table.insert(missing, pair[1] .. "/" .. pair[2]) end
    end
    if #missing > 0 then
        local msg = "SERVER REMOTES MISSING: " .. table.concat(missing, ", ")
        warn("[Null Protocol] " .. msg)
        if ENV.__NULL_REPORT then pcall(ENV.__NULL_REPORT, msg) end
    else
        print("[Null Protocol] server remote audit OK")
    end
end)

return result
