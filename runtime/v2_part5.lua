    connect(hum.Running,function(speed) if speed>.1 then play("walk",math.max(.5,speed/14)) else play("idle",1) end end)
    connect(hum.StateChanged,function(_,new)
        if new==Enum.HumanoidStateType.Jumping then play("jump",1)
        elseif new==Enum.HumanoidStateType.Freefall then play("fall",1) end
    end)
    play("idle",1)
end
local function revealCharacter(char)
    task.wait(1.05);if runtime.dead or not char.Parent then return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency=(v.Name=="HumanoidRootPart") and 1 or 0;pcall(function()v.LocalTransparencyModifier=0 end)
        elseif v:IsA("Decal") then v.Transparency=0 end
    end
end
local function attachInfo(plr,char)
    local head=char:WaitForChild("Head",8);if not head then return end
    local old=head:FindFirstChild("__FunCombatInfo");if old then old:Destroy() end
    local b=Instance.new("BillboardGui");b.Name="__FunCombatInfo";b.AlwaysOnTop=true;b.Size=UDim2.new(0,220,0,50);b.StudsOffset=Vector3.new(0,2.15,0);b.Adornee=head;b.Parent=head
    local n=Instance.new("TextLabel");n.BackgroundTransparency=1;n.Size=UDim2.new(1,0,.55,0);n.Font=Enum.Font.GothamBold;n.TextScaled=true;n.TextColor3=Color3.new(1,1,1);n.TextStrokeTransparency=.45;n.Text=plr.DisplayName;n.Parent=b
    local g=Instance.new("TextLabel");g.Name="GenderText";g.BackgroundTransparency=1;g.Position=UDim2.new(0,0,.55,0);g.Size=UDim2.new(1,0,.38,0);g.Font=Enum.Font.Gotham;g.TextScaled=true;g.TextColor3=Color3.fromRGB(220,220,230);g.TextStrokeTransparency=.55;g.Parent=b
    local function sync()g.Text=tostring(plr:GetAttribute("Gender") or "")end;sync();connect(plr:GetAttributeChangedSignal("Gender"),sync)
end
local function installChar(plr,char)
    task.spawn(revealCharacter,char);task.spawn(attachInfo,plr,char)
    local animateRan=false
    if plr==player and charScriptsTemplate then
        for _,src in ipairs(charScriptsTemplate:GetChildren()) do
            if not char:FindFirstChild(src.Name) then
                local c=src:Clone();freezeLocals(c);c.Parent=char;track(c)
                if c:IsA("LocalScript") and c.Name~="main" then
                    local ran=runLocal(c);if c.Name=="Animate" and ran then animateRan=true end
                end
            end
        end
    end
    task.delay(.5,function()if plr==player and not animateRan and char.Parent then fallbackR6(char) end end)
end
local function hookPlayer(plr)
    if plr.Character then task.spawn(installChar,plr,plr.Character) end
    connect(plr.CharacterAdded,function(c)task.spawn(installChar,plr,c)end)
end
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
connect(Players.PlayerAdded,hookPlayer)

-- Run preserved GUI and PlayerScripts after all roots are in their real locations.
for _,root in ipairs(guiRoots) do runTree(root) end
for _,root in ipairs(importedPlayerRoots) do runTree(root) end

-- Critical fallbacks in case Source is protected by the executor.
local function bindOnce(button,key,fn)
    if not button or not button:IsA("GuiButton") or button:GetAttribute(key) then return end
    button:SetAttribute(key,true);connect(button.Activated,fn)
end

local setInfo=attrSystem:WaitForChild("SetInfo")
local genderGui=pg:FindFirstChild("Gender")
if genderGui then
    local native=genderGui:FindFirstChild("Buttons",true)
    local nativeRan=native and native:IsA("LocalScript") and native:GetAttribute("__FCRan")
    if player:GetAttribute("Gender") then genderGui.Enabled=false else genderGui.Enabled=true end
    for _,b in ipairs(genderGui:GetDescendants()) do
        if b:IsA("TextButton") and (b.Text=="Male" or b.Text=="Female" or b.Text=="Fembxy") then
            if not nativeRan then bindOnce(b,"__FCGender",function()setInfo:FireServer("Gender",b.Text);genderGui.Enabled=false end) end
        end
    end
    connect(player:GetAttributeChangedSignal("Gender"),function()if player:GetAttribute("Gender") then genderGui.Enabled=false end end)
end

local emoteRemote=remotes:WaitForChild("Emote")
local emotes=pg:FindFirstChild("Emotes")
if emotes then
    emotes.Enabled=true
    local display=emotes:FindFirstChild("display")
    local buttonFrame=emotes:FindFirstChild("button")
    local opener=buttonFrame and buttonFrame:FindFirstChildWhichIsA("GuiButton",true)
    if display and opener then
        local native=buttonFrame:FindFirstChildWhichIsA("LocalScript",true)
        local nativeRan=native and native:GetAttribute("__FCRan")
        local open=false
        if not nativeRan then bindOnce(opener,"__FCEmoteOpen",function()
            open=not open
            TweenService:Create(display,TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=open and UDim2.new(.5,0,.6,0) or UDim2.new(.5,0,1.3,0)}):Play()
        end) end
        for _,b in ipairs(display:GetDescendants()) do
            if b:IsA("TextButton") and not nativeRan then bindOnce(b,"__FCEmote",function()
                local c=player.Character;if not c or c:GetAttribute("downed")==true or c:FindFirstChild("stun") then return end
                emoteRemote:FireServer(b.Name)
            end) end
        end
    end
end

local equipRemote=remotes:WaitForChild("EquipWeapon")
local weaponGui=pg:FindFirstChild("weapon")
local weaponOpen=pg:FindFirstChild("weaponGui")
if weaponGui and weaponOpen then
    local native=weaponOpen:FindFirstChildWhichIsA("LocalScript",true)
    local nativeRan=native and native:GetAttribute("__FCRan")
