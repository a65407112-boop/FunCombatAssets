-- Null Protocol diagnostic/runtime bridge v7
-- Critical UI actions are wired explicitly. Gameplay decisions remain server-authoritative.

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
label.Size = UDim2.new(0,760,0,48)
label.BackgroundColor3 = Color3.fromRGB(20,20,24)
label.BackgroundTransparency = .06
label.TextColor3 = Color3.new(1,1,1)
label.Font = Enum.Font.Code
label.TextSize = 16
label.TextWrapped = true
label.Text = "Null Protocol: v7 reached"
label.Parent = gui

local function status(text,bad)
    print("[Null Protocol] "..tostring(text))
    label.Text = "Null Protocol: "..tostring(text)
    if bad then
        label.BackgroundColor3 = Color3.fromRGB(100,20,20)
    else
        label.BackgroundColor3 = Color3.fromRGB(20,70,35)
    end
end

local function findEither(parent,clearName,tokenName)
    if not parent then return nil end
    return parent:FindFirstChild(clearName) or (tokenName and parent:FindFirstChild(tokenName))
end

local ok,result = xpcall(function()
    status("loading reconstructed UI",false)

    -- Use the last stable reconstruction build. v7 adds deterministic critical controllers after it.
    local url = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/7ae7fda612a2b8b88dc17d43ef1d528a2d01fdb3/loader_fixed.lua?cb="..tostring(os.clock())
    local src = game:HttpGet(url)
    local fn,err = loadstring(src,"NullProtocolStableRuntime")
    if not fn then error("stable runtime compile failed: "..tostring(err)) end
    local value = fn()

    -- Server-owned remote instances. Resolve both post-translation and opaque names.
    local remotes = findEither(RS,"Remotes","xaf2bb0d97d5d")
    local attrSystem = findEither(RS,"AttributeSystem","x3af6217d1a92")
    local remoteEvents = findEither(RS,"RemoteEvents","x06f340810381")

    local setInfo = findEither(attrSystem,"SetInfo","x967d386c24d6")
    local probe = remotes and remotes:FindFirstChild("__NPProbe")
    local equipWeapon = remotes and remotes:FindFirstChild("EquipWeapon")
    local visualBus = findEither(remotes,"TestAnimation","xe40a2326dbcf")

    -- Definitive server version probe when CompatV4 is published.
    local compat = RS:GetAttribute("__NPServerCompat")
    if probe and probe:IsA("RemoteFunction") then
        local pok,pver = pcall(function() return probe:InvokeServer("ping") end)
        if pok then compat=pver end
    end
    if compat=="compat-v4" then
        status("server CompatV4 ACK | wiring menus",false)
    elseif compat=="compat-v3" then
        status("server CompatV3 detected | v4 recommended",false)
    else
        status("SERVER COMPAT NOT DETECTED | published server is old",true)
    end

    -- Keep classic blocky R6 visible, but never reveal HumanoidRootPart.
    local function fixCharacter(c)
        if not c then return end
        local hum=c:FindFirstChildOfClass("Humanoid")
        if hum and hum.RigType~=Enum.HumanoidRigType.R6 then
            status("server character is not R6: "..tostring(hum.RigType),true)
            return
        end
        local body={"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
        for _,name in ipairs(body) do
            local p=c:FindFirstChild(name)
            if p and p:IsA("BasePart") then
                pcall(function()
                    p.Transparency=0
                    p.LocalTransparencyModifier=0
                end)
            end
        end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then
            pcall(function()
                hrp.Transparency=1
                hrp.LocalTransparencyModifier=0
            end)
        end
    end
    if plr.Character then task.defer(fixCharacter,plr.Character) end
    plr.CharacterAdded:Connect(function(c)
        task.wait(1.2)
        fixCharacter(c)
    end)

    -- Hitbox visualizer always begins OFF. Remove leftovers from previous runtime runs.
    local hitGui=pg:FindFirstChild("HitboxToggle")
    local hitToggle=hitGui and hitGui:FindFirstChild("Toggle")
    if hitToggle and hitToggle:IsA("BoolValue") then hitToggle.Value=false end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.Name=="hitbox_ref" then pcall(function() v:Destroy() end) end
    end

    -- Gender: explicit request -> wait for SERVER attribute acknowledgement.
    local GENDER_ATTR="qe8be68a176690a76"
    local genderGui=pg:FindFirstChild("Gender")

    local function syncGenderDisplay()
        local value=plr:GetAttribute(GENDER_ATTR)
        if not value then return end
        if genderGui then genderGui.Enabled=false end
        local c=plr.Character
        local head=c and c:FindFirstChild("Head")
        local info=head and head:FindFirstChild("Info")
        if info then
            for _,v in ipairs(info:GetDescendants()) do
                if v:IsA("TextLabel") then
                    if v.Name=="GenderText" or (v.Parent and v.Parent.Name=="GenderText") then
                        v.Text=tostring(value)
                    end
                end
            end
        end
    end
    plr:GetAttributeChangedSignal(GENDER_ATTR):Connect(syncGenderDisplay)
    syncGenderDisplay()

    if genderGui then
        for _,button in ipairs(genderGui:GetDescendants()) do
            if button:IsA("TextButton") and not button:GetAttribute("__NPDirectGender") then
                local compact=string.lower((button.Text or ""):gsub("%s+",""))
                if compact=="male" or compact=="female" or compact=="fembxy" then
                    button:SetAttribute("__NPDirectGender",true)
                    button.Activated:Connect(function()
                        local wanted=tostring(button.Text)
                        if not setInfo or not setInfo:IsA("RemoteEvent") then
                            genderGui.Enabled=true
                            status("GENDER FAILED: server SetInfo remote missing",true)
                            return
                        end
                        status("gender sent -> "..wanted,false)
                        setInfo:FireServer(GENDER_ATTR,wanted)
                        local deadline=os.clock()+5
                        while os.clock()<deadline and plr:GetAttribute(GENDER_ATTR)~=wanted do
                            task.wait(.05)
                        end
                        if plr:GetAttribute(GENDER_ATTR)==wanted then
                            genderGui.Enabled=false
                            syncGenderDisplay()
                            status("gender ACK <- server: "..wanted,false)
                        else
                            genderGui.Enabled=true
                            status("NO SERVER ACK FOR GENDER | server build/handler is dead",true)
                        end
                    end)
                end
            end
        end
    else
        status("Gender GUI missing after runtime mount",true)
    end

    -- weaponGui had two independent toggle handlers in the old runtime. Ensure one click
    -- produces exactly one final state even if those two cancel each other out.
    local weaponOpenGui=pg:FindFirstChild("weaponGui")
    local weaponGui=pg:FindFirstChild("weapon")
    if weaponOpenGui and weaponGui then
        for _,button in ipairs(weaponOpenGui:GetDescendants()) do
            if button:IsA("GuiButton") and not button:GetAttribute("__NPStableWeaponOpen") then
                button:SetAttribute("__NPStableWeaponOpen",true)
                button.Activated:Connect(function()
                    local before=weaponGui.Enabled
                    task.wait(.08)
                    if weaponGui.Enabled==before then
                        weaponGui.Enabled=not before
                    end
                end)
            end
        end
    end

    -- Weapon choices are requests. CompatV4/3 must approve with EQ on the server bus.
    if weaponGui then
        for _,button in ipairs(weaponGui:GetDescendants()) do
            if button:IsA("TextButton") and not button:GetAttribute("__NPWeaponRequest") then
                local tool=button:FindFirstChildWhichIsA("Tool",true)
                if tool then
                    button:SetAttribute("__NPWeaponRequest",true)
                    button.Activated:Connect(function()
                        if not equipWeapon or not equipWeapon:IsA("RemoteEvent") then
                            status("WEAPON FAILED: server EquipWeapon remote missing",true)
                            return
                        end
                        status("weapon request sent -> "..tool.Name,false)
                        equipWeapon:FireServer(tool.Name)
                    end)
                end
            end
        end
    end

    if visualBus and visualBus:IsA("RemoteEvent") then
        visualBus.OnClientEvent:Connect(function(op,...)
            if op=="EQ" then
                local name=(...)
                status("weapon ACK <- server: "..tostring(name),false)
            end
        end)
    end

    -- Simple direct fallback for the Hitbox toggle's visual control only.
    if hitGui and hitToggle then
        for _,button in ipairs(hitGui:GetDescendants()) do
            if button:IsA("GuiButton") and not button:GetAttribute("__NPHitboxFallback") then
                button:SetAttribute("__NPHitboxFallback",true)
                button.Activated:Connect(function()
                    local before=hitToggle.Value
                    task.wait(.05)
                    if hitToggle.Value==before then hitToggle.Value=not before end
                    for _,t in ipairs(hitGui:GetDescendants()) do
                        if t:IsA("TextLabel") and string.find(t.Text,"Hitboxes:",1,true) then
                            t.Text=hitToggle.Value and "Hitboxes: On" or "Hitboxes: Off"
                        end
                    end
                end)
            end
        end
    end

    -- Report the remotes that matter most instead of silently pretending everything is fine.
    local missing={}
    if not remotes then table.insert(missing,"Remotes") end
    if not setInfo then table.insert(missing,"SetInfo") end
    if not findEither(remotes,"GetUp","x3050ec664e12") then table.insert(missing,"GetUp") end
    if not findEither(remotes,"Emote","x5988a13e5f9e") then table.insert(missing,"Emote") end
    if not findEither(remotes,"Hit","x4ebfd059b5e5") then table.insert(missing,"Hit") end
    if not remoteEvents then table.insert(missing,"RemoteEvents") end
    if #missing>0 then
        status("SERVER REMOTES MISSING: "..table.concat(missing,", "),true)
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
