-- Null Protocol runtime v6 (entry file remains loader_v5.lua)
-- Keeps gameplay decisions on the server and reconstructs only client presentation.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- Wait briefly for the server compatibility bootstrap. It sets this only after
-- its compatibility remotes are ready, which avoids a race during join.
for _ = 1, 40 do
    if RS:GetAttribute("__NPServerCompat") then break end
    task.wait(.05)
end

-- CompatV3 intentionally creates a legacy ReplicatedStorage.Remotes/Ragdoll for
-- one old server module. Hide that alias locally before the opaque token folder
-- is translated to Remotes, otherwise client scripts see two folders with the same name.
local rawRemotes = RS:FindFirstChild("xaf2bb0d97d5d")
local legacyRemotes = RS:FindFirstChild("Remotes")
if rawRemotes and legacyRemotes and legacyRemotes ~= rawRemotes then
    pcall(function() legacyRemotes.Name = "__NPServerLegacyRemotes" end)
end

-- CompatV3 also supplies the clear CamShake event required by the old server
-- CombatFunctions. Keep that event as the client-facing CamShake and prevent the
-- unused opaque duplicate from receiving the same translated name locally.
if rawRemotes then
    local compatCam = rawRemotes:FindFirstChild("CamShake")
    local oldCam = rawRemotes:FindFirstChild("xd7ea1d7cbe734d57")
    if compatCam and oldCam then
        pcall(function() oldCam.Name = "__NPUnusedTokenCamShake" end)
    end
end

-- Start from the last stable reconstruction loader, but patch its generated core
-- so Tool LocalScripts do not start while the tools are still parked inside GUI.
local V4 = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/7ae7fda612a2b8b88dc17d43ef1d528a2d01fdb3/loader_fixed.lua"
local v4src = game:HttpGet(V4 .. "?cb=" .. tostring(os.clock()))

local injectionTail = [==[    return src
end

local ok,result=xpcall]=]

local patchedInjectionTail = [==[
    -- v6: defer LocalScripts inside Tool objects until the SERVER approves an equip.
    local oldClientCond='if inst:IsA("LocalScript") and inst:IsDescendantOf(game) and not inst:GetAttribute("__rt_started") then'
    local newClientCond='local __npToolRoot=((getgenv and getgenv()) or _G).__NULL_TOOL_ROOT; if inst:IsA("LocalScript") and inst:IsDescendantOf(game) and not inst:GetAttribute("__rt_started") and (not inst:FindFirstAncestorOfClass("Tool") or (__npToolRoot and inst:IsDescendantOf(__npToolRoot))) then'
    src=select(1,replaceOnce(src,oldClientCond,newClientCond))

    -- Tool scripts originally used RemoteEvents parented inside the Tool. Those
    -- Tool instances are presentation-only now, so route the two server calls to
    -- server-created global remotes instead.
    local oldToolCompile='local fn,er=loadstring(src,"="..inst:GetFullName())'
    local newToolCompile=[==[local __npSource=src
                if inst:FindFirstAncestorOfClass("Tool") then
                    __npSource=__npSource:gsub('script%.Parent:WaitForChild%("Dash"%)','rs:WaitForChild("Remotes"):WaitForChild("WeaponDash")')
                    __npSource=__npSource:gsub('Tool:WaitForChild%("SetMotor6D"%)','rs:WaitForChild("Remotes"):WaitForChild("WeaponMotor")')
                end
                local fn,er=loadstring(__npSource,"="..inst:GetFullName())]==]
    src=select(1,replaceOnce(src,oldToolCompile,newToolCompile))

    -- Expose a narrow restart hook. Initial runLocal() skips Tool scripts; the
    -- equip acknowledgement later runs only descendants of the approved Tool.
    local exposeToolRunner=[==[
do
    local __npEnv=(getgenv and getgenv()) or _G
    __npEnv.__NULL_RUN_TOOL=function(root)
        if not root or not root.Parent then return false end
        __npEnv.__NULL_TOOL_ROOT=root
        runLocal()
        __npEnv.__NULL_TOOL_ROOT=nil
        return true
    end
end
]==]
    src=select(1,insertAfter(src,"runLocal()",exposeToolRunner))

    return src
end

local ok,result=xpcall]=]

local ip = v4src:find(injectionTail, 1, true)
if not ip then
    error("Null Protocol v6: v4 injection patch point not found")
end
v4src = v4src:sub(1, ip - 1) .. patchedInjectionTail .. v4src:sub(ip + #injectionTail)

local fn, err = loadstring(v4src, "NullProtocolV6Base")
if not fn then error("Null Protocol v6: base compile failed: " .. tostring(err)) end
local result = fn()

local pg = plr:WaitForChild("PlayerGui")

local statusGui
local function showStatus(text, bad)
    warn("[Null Protocol] " .. tostring(text))
    pcall(function()
        if ENV.__NULL_REPORT then ENV.__NULL_REPORT(text) end
    end)
    pcall(function()
        if not statusGui or not statusGui.Parent then
            statusGui = Instance.new("ScreenGui")
            statusGui.Name = "__NPServerStatus"
            statusGui.ResetOnSpawn = false
            statusGui.DisplayOrder = 1000001
            statusGui.IgnoreGuiInset = true
            statusGui.Parent = pg
            local label = Instance.new("TextLabel")
            label.Name = "Status"
            label.AnchorPoint = Vector2.new(.5, 0)
            label.Position = UDim2.new(.5, 0, 0, 8)
            label.Size = UDim2.new(0, 760, 0, 44)
            label.BackgroundTransparency = .08
            label.TextScaled = false
            label.TextSize = 16
            label.TextWrapped = true
            label.Font = Enum.Font.Code
            label.TextColor3 = Color3.new(1,1,1)
            label.Parent = statusGui
        end
        local label = statusGui:FindFirstChild("Status")
        if label then
            label.BackgroundColor3 = bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,70,35)
            label.Text = "Null Protocol: " .. tostring(text)
        end
    end)
end
local function clearStatus()
    pcall(function()
        if statusGui then statusGui:Destroy(); statusGui=nil end
    end)
end

-- The server proxy is deliberately invisible. Reveal only the visible R6 body.
-- HumanoidRootPart MUST stay invisible; making it visible was the cube around torso.
local BODY = {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
local function setBaseVisible(char, visible)
    if not char or not char.Parent then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.RigType ~= Enum.HumanoidRigType.R6 then
        showStatus("SERVER CHARACTER IS NOT R6: " .. tostring(hum.RigType), true)
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
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        pcall(function() hrp.Transparency = 1 end)
        pcall(function() hrp.LocalTransparencyModifier = 0 end)
    end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local h=v:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then pcall(function() h.Transparency=tr end) end
        elseif visible and v:IsA("CharacterMesh") then
            pcall(function() v:Destroy() end)
        end
    end
end
ENV.__NULL_SET_BASE_VISIBLE=setBaseVisible

local function watchCharacter(char)
    task.defer(function() setBaseVisible(char,true) end)
    task.delay(1.35,function()
        if char and char.Parent then setBaseVisible(char,true) end
    end)
end
if plr.Character then watchCharacter(plr.Character) end
plr.CharacterAdded:Connect(watchCharacter)

-- Hitbox visualizer must start OFF. Remove stale debug boxes left by a previous
-- attack/runtime and prevent new hitbox_ref parts while the toggle is false.
local hitGui=pg:FindFirstChild("HitboxToggle")
local hitToggle=hitGui and hitGui:FindFirstChild("Toggle")
if hitToggle and hitToggle:IsA("BoolValue") then hitToggle.Value=false end
for _,v in ipairs(workspace:GetDescendants()) do
    if v.Name=="hitbox_ref" then pcall(function() v:Destroy() end) end
end
workspace.DescendantAdded:Connect(function(v)
    if v.Name=="hitbox_ref" and hitToggle and not hitToggle.Value then
        task.defer(function() if v.Parent then pcall(function() v:Destroy() end) end end)
    end
end)

local remotes=RS:WaitForChild("Remotes",15)
local bus=remotes and remotes:WaitForChild("TestAnimation",15)

-- Keep base body visibility synchronized with server morph decisions.
if bus and bus:IsA("RemoteEvent") then
    bus.OnClientEvent:Connect(function(op,...)
        local a={...}
        if op=="M+" then
            setBaseVisible(a[1],false)
        elseif op=="M-" then
            task.defer(function() setBaseVisible(a[1],true) end)
        end
    end)
end

-- Bridge the one legacy Ragdoll event used by the untouched opaque module.
if legacyRemotes and legacyRemotes.Parent then
    local rag=legacyRemotes:FindFirstChild("Ragdoll")
    if rag and rag:IsA("RemoteEvent") then
        rag.OnClientEvent:Connect(function(toggle)
            local char=plr.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health<=0 then return end
            if toggle then
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
                hum:ChangeState(Enum.HumanoidStateType.Physics)
                hum.AutoRotate=false
            else
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.AutoRotate=true
            end
        end)
    end
end

-- Gender display follows SERVER attribute only. The v4 click fallback sends SetInfo;
-- this block makes the result visible next to the name as soon as replication arrives.
local GENDER_ATTR="qe8be68a176690a76"
local function syncGender()
    local value=plr:GetAttribute(GENDER_ATTR)
    if not value then return end
    local gender=pg:FindFirstChild("Gender")
    if gender then gender.Enabled=false end
    local char=plr.Character
    local head=char and char:FindFirstChild("Head")
    local info=head and head:FindFirstChild("Info")
    if info then
        for _,v in ipairs(info:GetDescendants()) do
            if v:IsA("TextLabel") and (v.Name=="GenderText" or (v.Parent and v.Parent.Name=="GenderText")) then
                v.Text=tostring(value)
            end
        end
    end
end
plr:GetAttributeChangedSignal(GENDER_ATTR):Connect(syncGender)
syncGender()

local gender=pg:FindFirstChild("Gender")
if gender then
    for _,v in ipairs(gender:GetDescendants()) do
        if v:IsA("TextButton") then
            local t=string.lower((v.Text or ""):gsub("%s+",""))
            if t=="male" or t=="female" or t=="fembxy" then
                v.Activated:Connect(function()
                    task.delay(2,function()
                        if not plr:GetAttribute(GENDER_ATTR) then
                            showStatus("SERVER DID NOT ACCEPT GENDER - WRONG/OLD SERVER BUILD",true)
                        end
                    end)
                end)
            end
        end
    end
end

-- Weapon menu: button click is a REQUEST. Nothing is moved into Backpack until
-- CompatV3 answers with EQ through the server visual bus.
local weaponGui=pg:FindFirstChild("weapon")
local equipRemote=remotes and remotes:FindFirstChild("EquipWeapon")
local weaponAnimReady=false

local function findWeaponTool(name)
    if not weaponGui then return nil end
    for _,v in ipairs(weaponGui:GetDescendants()) do
        if v:IsA("Tool") and v.Name==name then return v end
    end
end

if weaponGui then
    for _,button in ipairs(weaponGui:GetDescendants()) do
        if button:IsA("TextButton") then
            local tool=button:FindFirstChildWhichIsA("Tool",true)
            if tool and not button:GetAttribute("__NPWeaponRequest") then
                button:SetAttribute("__NPWeaponRequest",true)
                button.Activated:Connect(function()
                    if not equipRemote or not equipRemote:IsA("RemoteEvent") then
                        showStatus("SERVER EquipWeapon REMOTE MISSING",true)
                        return
                    end
                    showStatus("requesting weapon: "..tool.Name,false)
                    equipRemote:FireServer(tool.Name)
                end)
            end
        end
    end
end

if bus and bus:IsA("RemoteEvent") then
    bus.OnClientEvent:Connect(function(op,...)
        if op~="EQ" then return end
        local name=(...)
        task.spawn(function()
            showStatus("server approved "..tostring(name).."; loading weapon assets",false)
            if not weaponAnimReady then
                local loadAnim=ENV.__NULL_LOAD_ANIM
                if not loadAnim then
                    showStatus("weapon animation loader missing",true)
                    return
                end
                local okAnim,animErr=loadAnim("anim_bat.lua")
                if not okAnim then
                    showStatus("anim_bat load failed: "..tostring(animErr),true)
                    return
                end
                weaponAnimReady=true
            end

            local tool=findWeaponTool(tostring(name))
            if not tool then
                showStatus("approved weapon not found in GUI: "..tostring(name),true)
                return
            end
            tool.Parent=plr:WaitForChild("Backpack")
            local runTool=ENV.__NULL_RUN_TOOL
            if not runTool then
                showStatus("Tool LocalScript runner missing",true)
                return
            end
            runTool(tool)
            if weaponGui then weaponGui.Enabled=false end
            clearStatus()
        end)
    end)
end

-- Definitive server health check. This distinguishes a client/menu bug from the
-- old server build simply never running its gameplay bootstrap.
task.spawn(function()
    task.wait(3)
    local compat=RS:GetAttribute("__NPServerCompat")
    if compat~="compat-v3" then
        showStatus("SERVER BUILD IS NOT CompatV3 (published server is still old)",true)
        return
    end
    local char=plr.Character
    local gameplayReady = plr:GetAttribute("qf18ae6e042b0ad7b")~=nil
        and char and char:GetAttribute("q1199c814b8f7a3e1")~=nil
    if not gameplayReady then
        showStatus("SERVER COMPAT PRESENT, BUT GAMEPLAY BOOTSTRAP DID NOT START",true)
        return
    end
    print("[Null Protocol] CompatV3 server + gameplay bootstrap OK")
end)

return result
