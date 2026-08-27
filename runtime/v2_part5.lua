    connect(hum.Jumping,function(isJumping) if isJumping and not paused then play("jump",.05,1) end end)
    connect(hum.FreeFalling,function(isFalling) if isFalling and not paused then play("fall",.08,1) end end)
    connect(hum.Climbing,function(speed) if not paused and math.abs(speed)>.05 then play("climb",.1,math.max(.2,math.abs(speed)/12)) end end)
    connect(hum.Seated,function(isSeated) if not paused and isSeated then play("sit",.12,1) elseif not isSeated then ctl:resume() end end)
    ctl:resume()
end

local function revealCharacter(char)
    task.wait(1.05);if runtime.dead or not char.Parent then return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency=(v.Name=="HumanoidRootPart") and 1 or 0;pcall(function()v.LocalTransparencyModifier=0 end)
        elseif v:IsA("Decal") then v.Transparency=0 end
    end
end

-- Original source-place overhead presentation. The nickname/health/fun widget is
-- the native ReplicatedStorage.stats RBXM, not a replacement drawn by this loader.
local genderFront={Female=Color3.fromRGB(170,86,162),Male=Color3.fromRGB(27,175,158),Fembxy=Color3.fromRGB(72,0,130)}
local genderBack={Female=Color3.fromRGB(35,23,34),Male=Color3.fromRGB(26,42,53),Fembxy=Color3.fromRGB(26,42,53)}
local denk=Font.new("rbxasset://fonts/families/DenkOne.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
local function makeOriginalInfo(plr,head)
    local old=head:FindFirstChild("Info");if old and old:GetAttribute("__FCClientInfo") then old:Destroy() end
    local info=Instance.new("BillboardGui");info.Name="Info";info:SetAttribute("__FCClientInfo",true)
    info.Active=true;info.AlwaysOnTop=false;info.Brightness=1;info.Enabled=true;info.LightInfluence=0;info.MaxDistance=50
    info.Size=UDim2.new(4.2,0,1.25,0);info.StudsOffset=Vector3.new(0,2,0);info.Adornee=head;info.Parent=head;track(info)
    local gender=Instance.new("TextLabel");gender.Name="GenderText";gender.BackgroundTransparency=1
    gender.Position=UDim2.new(0,0,.75,0);gender.Size=UDim2.new(1,0,.25,0);gender.FontFace=denk;gender.TextScaled=true;gender.TextSize=14
    gender.TextStrokeTransparency=.85;gender.TextColor3=Color3.fromRGB(116,116,116);gender.ZIndex=2;gender.Parent=info
    local shadow=Instance.new("TextLabel");shadow.Name="Background";shadow.BackgroundTransparency=1;shadow.Position=UDim2.new(0,2,0,2)
    shadow.Size=UDim2.new(1,0,1,0);shadow.FontFace=denk;shadow.TextScaled=true;shadow.TextSize=14;shadow.TextStrokeTransparency=.85
    shadow.TextColor3=Color3.fromRGB(38,38,38);shadow.ZIndex=1;shadow.Parent=gender
    local function syncGender()
        local g=tostring(plr:GetAttribute("Gender") or "")
        gender.Text=g;shadow.Text=g
        if genderFront[g] then gender.TextColor3=genderFront[g];shadow.TextColor3=genderBack[g] end
    end
    syncGender();connect(plr:GetAttributeChangedSignal("Gender"),syncGender)
end
local function attachOriginalHud(plr,char)
    local head=char:WaitForChild("Head",8);local hum=char:FindFirstChildOfClass("Humanoid");if not head then return end
    local old=head:FindFirstChild("stats");if old and old:GetAttribute("__FCClientStats") then old:Destroy() end
    local template=RS:FindFirstChild("stats")
    if template and template:IsA("BillboardGui") then
        local stats=template:Clone();stats.Name="stats";stats:SetAttribute("__FCClientStats",true);stats.Adornee=head;stats.Parent=head;track(stats)
        local frame=stats:FindFirstChild("Frame")
        local name=frame and frame:FindFirstChild("TextLabel");if name then name.Text=plr.DisplayName end
        local healthFill=frame and frame:FindFirstChild("health") and frame.health:FindFirstChild("Frame")
        local funFill=frame and frame:FindFirstChild("fun") and frame.fun:FindFirstChild("Frame")
        local function setHealth(hp)
            if not healthFill or not hum then return end
            local ratio=math.clamp((tonumber(hp) or hum.Health)/math.max(hum.MaxHealth,1),0,1)
            TweenService:Create(healthFill,TweenInfo.new(.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(ratio,0,1,0)}):Play()
        end
        local function setFun()
            if not funFill then return end
            local ratio=math.clamp(tonumber(char:GetAttribute("funMeter")) or 0,0,1)
            TweenService:Create(funFill,TweenInfo.new(.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size=UDim2.new(ratio,0,1,0)}):Play()
        end
        if hum then setHealth(hum.Health);connect(hum.HealthChanged,setHealth) end
        setFun();connect(char:GetAttributeChangedSignal("funMeter"),setFun)
    end
    makeOriginalInfo(plr,head)
end

local function installChar(plr,char)
    task.spawn(revealCharacter,char);task.spawn(attachOriginalHud,plr,char)
    local animateRan=false
    if plr==player and charScriptsTemplate then
        for _,src in ipairs(charScriptsTemplate:GetChildren()) do
            if not char:FindFirstChild(src.Name) then
                local c=src:Clone();freezeLocals(c);c.Parent=char;track(c)
                if c:IsA("LocalScript") and c.Name~="main" then local ran=runLocal(c);if c.Name=="Animate" and ran then animateRan=true end end
            end
        end
    end
    task.delay(.45,function()if plr==player and not animateRan and char.Parent then fallbackR6(char) end end)
end
local function hookPlayer(plr)
    if plr.Character then task.spawn(installChar,plr,plr.Character) end
    connect(plr.CharacterAdded,function(c)task.spawn(installChar,plr,c)end)
end
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
connect(Players.PlayerAdded,hookPlayer)

-- Run preserved client code only after every available native root is mounted.
for _,root in ipairs(guiRoots) do runTree(root) end
for _,root in ipairs(importedPlayerRoots) do runTree(root) end

local function bindOnce(button,key,fn)
    if not button or not button:IsA("GuiButton") or button:GetAttribute(key) then return end
    button:SetAttribute(key,true);connect(button.Activated,fn)
end

-- Original Gender contract: SetInfo("Gender", value). Wait for server ACK before
-- hiding the selector, matching the source place rather than hiding optimistically.
local setInfo=attrSystem:WaitForChild("SetInfo")
local genderGui=pg:FindFirstChild("Gender")
if genderGui then
    local native=genderGui:FindFirstChild("Buttons",true);local nativeRan=native and native:IsA("LocalScript") and native:GetAttribute("__FCRan")
    genderGui.Enabled=not not (not player:GetAttribute("Gender"))
    if not nativeRan then
        for _,b in ipairs(genderGui:GetDescendants()) do
            if b:IsA("TextButton") and (b.Text=="Male" or b.Text=="Female" or b.Text=="Fembxy") then
                bindOnce(b,"__FCGender",function()setInfo:FireServer("Gender",b.Text)end)
            end
        end
    end
    connect(player:GetAttributeChangedSignal("Gender"),function()if player:GetAttribute("Gender") then genderGui.Enabled=false end end)
end

-- Exact original Emotes menu motion/sounds and server request flow.
local emoteRemote=remotes:WaitForChild("Emote")
local emotes=pg:FindFirstChild("Emotes")
if emotes then
    emotes.Enabled=true
    local display=emotes:FindFirstChild("display");local buttonFrame=emotes:FindFirstChild("button")
    local opener=buttonFrame and buttonFrame:FindFirstChildWhichIsA("GuiButton",true)
    local native=buttonFrame and buttonFrame:FindFirstChildWhichIsA("LocalScript",true);local nativeRan=native and native:GetAttribute("__FCRan")
    if display and opener and not nativeRan then
        local open=false;local debounce=false
        bindOnce(opener,"__FCEmoteOpen",function()
            if debounce then return end;debounce=true;open=not open
            local sid=open and "rbxassetid://4850864425" or "rbxassetid://1524543584"
            local s=Instance.new("Sound");s.SoundId=sid;s.Parent=opener;s:Play();Debris:AddItem(s,4)
            TweenService:Create(display,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=open and UDim2.new(.5,0,.6,0) or UDim2.new(.5,0,1.3,0)}):Play()
            task.delay(1,function()debounce=false end)
        end)
        for _,b in ipairs(display:GetDescendants()) do
            if b:IsA("TextButton") then bindOnce(b,"__FCEmote",function()
                local c=player.Character;if not c or c:GetAttribute("downed")==true or c:GetAttribute("carrying")==true or c:FindFirstChild("stun") then return end
                emoteRemote:FireServer(b.Name)
            end) end
        end
        TweenService:Create(buttonFrame,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.new(0,30,0,10)}):Play()
        task.delay(.4,function()if buttonFrame.Parent then TweenService:Create(buttonFrame,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Rotation=-2}):Play() end end)
    end
end

-- Original Workspace/Music playlist, restored as presentation because the thin
-- server build intentionally contains no client audio hierarchy.
local musicIds={1845341094,9046863253,9046864509,9043887091,1847506405,1837871067,1843468325,1845490105}
local musicFolder=Instance.new("Folder");musicFolder.Name="__FCMusic";musicFolder.Parent=game:GetService("SoundService");track(musicFolder)
local music=Instance.new("Sound");music.Name="currentSound";music.Parent=musicFolder
local function chooseMusic()music.SoundId="rbxassetid://"..tostring(musicIds[math.random(1,#musicIds)])end
chooseMusic();music:Play()
task.spawn(function()
    while not runtime.dead and music.Parent do
        music.Ended:Wait();if runtime.dead or not music.Parent then break end
        task.wait(3);if runtime.dead or not music.Parent then break end;chooseMusic();music:Play()
    end
end)

-- Weapon/menu setup continues in part 6.
