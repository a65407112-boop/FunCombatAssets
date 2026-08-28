local G=(getgenv and getgenv()) or _G
if G.FEAnimPackRunCleanup then pcall(G.FEAnimPackRunCleanup) end

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local player=Players.LocalPlayer
local charConn, guiConn
local touched={}

local function silence(char)
    if not char then return end
    local animate=char:FindFirstChild("Animate")
    if animate then
        touched[animate]=animate.Disabled
        animate.Disabled=true
    end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local animator=hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _,track in ipairs(animator:GetPlayingAnimationTracks()) do pcall(function() track:Stop(0.08) end) end
    end
end

local restored=false
local function restoreAnimate()
    if restored then return end
    restored=true
    if charConn then charConn:Disconnect() end
    if guiConn then guiConn:Disconnect() end
    for animate,wasDisabled in pairs(touched) do
        if animate and animate.Parent then animate.Disabled=wasDisabled end
    end
    G.FEAnimPackRunCleanup=nil
end
G.FEAnimPackRunCleanup=restoreAnimate

silence(player.Character)
charConn=player.CharacterAdded:Connect(function(char)
    task.wait(0.35)
    silence(char)
end)

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/"
local src=game:HttpGet(BASE.."loader.lua")
src=src:gsub('BASE %.%. "animations%.lua"','BASE .. "animations_runtime.lua"')
local fn,compileErr=loadstring(src)
if not fn then restoreAnimate(); error(compileErr) end
local ok,runErr=pcall(fn)
if not ok then restoreAnimate(); error(runErr) end

local gui=CoreGui:FindFirstChild("FEAnimPack") or player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("FEAnimPack")
if gui then
    guiConn=gui.AncestryChanged:Connect(function(_,parent)
        if parent==nil then restoreAnimate() end
    end)
end
