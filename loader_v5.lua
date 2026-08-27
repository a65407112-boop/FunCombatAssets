-- Null Protocol visible stable bootstrap
-- Keep this file deliberately small: show status first, then run the known-good runtime.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G

local old = pg:FindFirstChild("__NPBootstrap")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "__NPBootstrap"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000002
gui.IgnoreGuiInset = true
gui.Parent = pg

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(.5,0)
label.Position = UDim2.new(.5,0,0,8)
label.Size = UDim2.new(0,760,0,46)
label.BackgroundColor3 = Color3.fromRGB(20,20,24)
label.BackgroundTransparency = .06
label.TextColor3 = Color3.new(1,1,1)
label.Font = Enum.Font.Code
label.TextSize = 16
label.TextWrapped = true
label.Text = "Null Protocol: latest loader reached"
label.Parent = gui

local function status(text,bad)
    print("[Null Protocol] "..tostring(text))
    label.Text = "Null Protocol: "..tostring(text)
    label.BackgroundColor3 = bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,70,35)
end

local ok,result = xpcall(function()
    status("loading stable runtime",false)
    local url = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/7ae7fda612a2b8b88dc17d43ef1d528a2d01fdb3/loader_fixed.lua?cb="..tostring(os.clock())
    local src = game:HttpGet(url)
    local fn,err = loadstring(src,"NullProtocolStableRuntime")
    if not fn then error("stable runtime compile failed: "..tostring(err)) end
    local value = fn()

    -- Keep classic R6 visible, but HumanoidRootPart must stay invisible.
    local function fixCharacter(c)
        if not c then return end
        local hum=c:FindFirstChildOfClass("Humanoid")
        if hum and hum.RigType~=Enum.HumanoidRigType.R6 then
            status("server character is not R6: "..tostring(hum.RigType),true)
            return
        end
        for _,name in ipairs({"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}) do
            local p=c:FindFirstChild(name)
            if p and p:IsA("BasePart") then
                pcall(function() p.Transparency=0; p.LocalTransparencyModifier=0 end)
            end
        end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then
            pcall(function() hrp.Transparency=1; hrp.LocalTransparencyModifier=0 end)
        end
    end
    if plr.Character then task.defer(fixCharacter,plr.Character) end
    plr.CharacterAdded:Connect(function(c) task.wait(1.2); fixCharacter(c) end)

    -- Hitbox debug must start disabled.
    local hgui=pg:FindFirstChild("HitboxToggle")
    local toggle=hgui and hgui:FindFirstChild("Toggle")
    if toggle and toggle:IsA("BoolValue") then toggle.Value=false end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.Name=="hitbox_ref" then pcall(function() v:Destroy() end) end
    end

    task.wait(2)
    local compat=RS:GetAttribute("__NPServerCompat")
    if compat=="compat-v3" then
        status("CompatV3 detected | stable runtime loaded",false)
    else
        status("runtime loaded | server is not CompatV3",true)
    end

    return value
end,function(e)
    local msg=tostring(e)
    if debug and debug.traceback then msg=debug.traceback(msg,2) end
    status(msg,true)
    return msg
end)

ENV.__NP_BOOTSTRAP_GUI=gui
return ok and result or nil