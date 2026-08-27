-- FunCombat native presentation polish v2.2
-- Restores presentation behavior from the original place while keeping combat server-authoritative.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local ENV=(getgenv and getgenv()) or _G
local api=ENV.__FC_NATIVE_API
if not api then error("FunCombat v2.2: native API missing") end
local runtime=api.runtime
local connect=api.connect
local track=api.track
local remotes=api.remotes
local ensureAnimation=api.ensureAnimation
local Anim=api.Anim

local function setStatus(s)
    if api.status then pcall(api.status,s,false) end
end
setStatus("v2.2 restoring original presentation details")

-- ---------------------------------------------------------------------------
-- ORIGINAL OVERHEAD INFO
-- Original source: ServerScriptService/AttributeSystem/AttributeSystem/Info.
-- Hierarchy and colors match the original server script instead of the v2
-- temporary __FunCombatInfo billboard.
-- ---------------------------------------------------------------------------
local function genderColors(value)
    if value=="Female" then return Color3.fromRGB(170,86,162),Color3.fromRGB(35,23,34) end
    if value=="Male" then return Color3.fromRGB(27,175,158),Color3.fromRGB(26,42,53) end
    if value=="Fembxy" then return Color3.fromRGB(72,0,130),Color3.fromRGB(26,42,53) end
    return Color3.fromRGB(116,116,116),Color3.fromRGB(38,38,38)
end
local function makeText(parent,name,z)
    local t=Instance.new("TextLabel")
    t.Name=name;t.BackgroundTransparency=1;t.TextScaled=true;t.TextWrapped=true
    t.TextXAlignment=Enum.TextXAlignment.Center;t.TextYAlignment=Enum.TextYAlignment.Center
    t.TextStrokeColor3=Color3.new(0,0,0);t.TextStrokeTransparency=.85;t.ZIndex=z
    t.Parent=parent
    return t
end
local function installOriginalInfo(plr,char)
    local head=char:WaitForChild("Head",8);if not head then return end
    local fake=head:FindFirstChild("__FunCombatInfo");if fake then fake:Destroy() end
    local old=head:FindFirstChild("Info");if old then old:Destroy() end
    local info=Instance.new("BillboardGui")
    info.Name="Info";info.Adornee=head;info.Enabled=true;info.AlwaysOnTop=false
    info.Size=UDim2.new(4.2,0,1.25,0);info.StudsOffset=Vector3.new(0,2,0)
    info.MaxDistance=50;info.LightInfluence=0;info.Parent=head;track(info)

    local gender=makeText(info,"GenderText",2)
    gender.Position=UDim2.new(0,0,.75,0);gender.Size=UDim2.new(1,0,.25,0)
    local genderBg=makeText(gender,"Background",1)
    genderBg.Position=UDim2.new(0,2,0,2);genderBg.Size=UDim2.new(1,0,1,0)

    local name=makeText(info,"NameText",2)
    name.Position=UDim2.new(0,0,.425,0);name.Size=UDim2.new(1,0,.35,0)
    local nameBg=makeText(name,"Background",1)
    nameBg.Position=UDim2.new(0,2,0,2);nameBg.Size=UDim2.new(1,0,1,0)
    name.Text=plr.DisplayName;nameBg.Text=plr.DisplayName
    name.TextColor3=Color3.new(1,1,1);nameBg.TextColor3=Color3.fromRGB(39,39,39)

    local function syncGender()
        local value=tostring(plr:GetAttribute("Gender") or "N/A [N/A]")
        gender.Text=value;genderBg.Text=value
        local fg,bg=genderColors(plr:GetAttribute("Gender"))
        gender.TextColor3=fg;genderBg.TextColor3=bg
    end
    syncGender();connect(plr:GetAttributeChangedSignal("Gender"),syncGender)
end
local function hookInfo(plr)
    if plr.Character then task.spawn(installOriginalInfo,plr,plr.Character) end
    connect(plr.CharacterAdded,function(c)task.spawn(installOriginalInfo,plr,c)end)
end
for _,p in ipairs(Players:GetPlayers()) do hookInfo(p) end
connect(Players.PlayerAdded,hookInfo)

-- ---------------------------------------------------------------------------
-- ORIGINAL MUSIC
-- Workspace/Music from the source place used this exact playlist and selected
-- another random track three seconds after Ended.
-- ---------------------------------------------------------------------------
local MUSIC={1845341094,9046863253,9046864509,9043887091,1847506405,1837871067,1843468325,1845490105}
local oldMusic=workspace:FindFirstChild("__FCOriginalMusic")
if oldMusic then oldMusic:Destroy() end
local musicFolder=Instance.new("Folder");musicFolder.Name="__FCOriginalMusic";musicFolder.Parent=workspace;track(musicFolder)
local currentSound=Instance.new("Sound");currentSound.Name="currentSound";currentSound.Volume=.5;currentSound.Parent=musicFolder
local function nextSong()
    if runtime.dead or not currentSound.Parent then return end
    currentSound.SoundId="rbxassetid://"..MUSIC[math.random(1,#MUSIC)]
    currentSound.TimePosition=0;currentSound:Play()
end
connect(currentSound.Ended,function()task.delay(3,nextSong)end)
nextSong()

-- ---------------------------------------------------------------------------
-- ORIGINAL EMOTES
-- Clone the already-imported original GUI to clear v2/native event connections,
-- then wire the original behavior exactly. Server still validates and broadcasts.
-- ---------------------------------------------------------------------------
local emoteRemote=remotes:WaitForChild("Emote")
local oldEmotes=pg:FindFirstChild("Emotes")
if oldEmotes then
    local emotes=oldEmotes:Clone();oldEmotes:Destroy();emotes.Name="Emotes";emotes.Enabled=true;emotes.Parent=pg;track(emotes)
    for _,d in ipairs(emotes:GetDescendants()) do if d:IsA("LocalScript") then d.Disabled=true end end
    local display=emotes:FindFirstChild("display")
    local buttonFrame=emotes:FindFirstChild("button")
    local opener=buttonFrame and buttonFrame:FindFirstChild("ImageButton")
    local onSFX=buttonFrame and buttonFrame:FindFirstChild("LocalScript") and buttonFrame.LocalScript:FindFirstChild("onSFX")
    local offSFX=buttonFrame and buttonFrame:FindFirstChild("LocalScript") and buttonFrame.LocalScript:FindFirstChild("offSFX")
    local shown=false;local debounce=false
    if display and opener then
        connect(opener.Activated,function()
            if debounce then return end;debounce=true;shown=not shown
            TweenService:Create(display,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=shown and UDim2.new(.5,0,.6,0) or UDim2.new(.5,0,1.3,0)}):Play()
            local s=(shown and onSFX or offSFX);if s and s:IsA("Sound") then s:Play() end
            task.delay(1,function()debounce=false end)
        end)
        local vert=TweenService:Create(buttonFrame,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.new(0,30,0,10)})
        local hor=TweenService:Create(buttonFrame,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Rotation=-2})
        vert:Play();task.delay(.4,function()if buttonFrame.Parent then hor:Play() end end)
    end
    if display then
        for _,b in ipairs(display:GetDescendants()) do
            if b:IsA("TextButton") then
                connect(b.Activated,function()
                    local c=player.Character;if not c then return end
                    if c:FindFirstChild("stun") or c:FindFirstChild("carrying") or c:GetAttribute("downed")==true then return end
                    emoteRemote:FireServer(b.Name)
                end)
            end
        end
    end
end

-- Extra renderer for server-authorized emotes. This uses the native KeyframeSequence
-- pack directly, so an emote does not depend on an imported LocalScript surviving Xeno.
local bus=remotes:WaitForChild("TestAnimation")
local emoteHandles=setmetatable({},{__mode="k"})
connect(bus.OnClientEvent,function(op,...)
    if op~="A" then return end
    local a={...};local id,path,char=a[1],a[2],a[3]
    if type(path)~="string" or path:sub(1,7)~="Emotes/" or not char then return end
    task.spawn(function()
        local seq=ensureAnimation(path)
        if seq and char.Parent then
            local prev=emoteHandles[char];if prev then Anim.StopAnimation(prev) end
            emoteHandles[char]=Anim.PlayAnimation(seq,char)
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- ORIGINAL R6 LEANING
-- Exact constants/math from StarterCharacterScripts/Leaning. This removes the
-- stiff snap when changing direction that the generic v2 fallback introduced.
-- ---------------------------------------------------------------------------
local function installLeaning(char)
    local hum=char:WaitForChild("Humanoid",5);local root=char:WaitForChild("HumanoidRootPart",5)
    if not hum or not root then return end
    local m6d
    if hum.RigType==Enum.HumanoidRigType.R15 then
        local lower=char:FindFirstChild("LowerTorso");m6d=lower and lower:FindFirstChild("Root")
    else m6d=root:FindFirstChild("RootJoint") end
    if not m6d then return end
    local original=m6d.C0
    connect(RunService.Heartbeat,function(dt)
        if runtime.dead or not char.Parent then return end
        if not char:GetAttribute("stun") and not char:GetAttribute("downed") then
            local direction=root.CFrame:VectorToObjectSpace(hum.MoveDirection)
            local momentum=root.CFrame:VectorToObjectSpace(root.Velocity)*.006
            momentum=Vector3.new(math.clamp(math.abs(momentum.X),.13,.13),0,math.clamp(math.abs(momentum.Z),.13,.13))
            local x=direction.X*momentum.X;local z=(direction.Z*momentum.Z)/2
            local cf
            if hum.RigType==Enum.HumanoidRigType.R15 then cf=CFrame.Angles(z,0,-x) else cf=CFrame.Angles(-z,-x,0) end
            m6d.C0=m6d.C0:Lerp(original*cf,math.clamp(dt*7,0,1))
        end
    end)
end
if player.Character then task.spawn(installLeaning,player.Character) end
connect(player.CharacterAdded,function(c)task.spawn(installLeaning,c)end)

-- ---------------------------------------------------------------------------
-- ORIGINAL WEAPON PRESENTATION
-- Keep v2's server-safe attack request, but restore the original local flourish,
-- swing/unequip animation cadence, swing pitch, trail and flash presentation.
-- ---------------------------------------------------------------------------
local function playSeq(path,char)
    task.spawn(function()
        local seq=ensureAnimation(path);if seq and char and char.Parent then Anim.PlayAnimation(seq,char) end
    end)
end
local wiredTools=setmetatable({},{__mode="k"})
local function playClone(sound,parent,speed)
    if not sound or not sound:IsA("Sound") then return end
    local c=sound:Clone();c.Parent=parent or workspace.CurrentCamera;if speed then c.PlaybackSpeed=speed end;c:Play();Debris:AddItem(c,8)
end
local function wireOriginalWeapon(tool)
    if not tool:IsA("Tool") or wiredTools[tool] then return end;wiredTools[tool]=true
    local handle=tool:FindFirstChild("Handle");if not handle then return end
    local combo=1;local busy=false
    connect(tool.Equipped,function()
        busy=true;playClone(handle:FindFirstChild("Equip"),handle);playSeq("bat/flourish",player.Character)
        task.delay(1.5,function()if tool.Parent then playClone(handle:FindFirstChild("Equip2"),handle) end end)
        task.delay(1.75,function()busy=false end)
    end)
    connect(tool.Activated,function()
        if busy then return end
        local c=player.Character;if not c or c:FindFirstChild("stun") or c:FindFirstChild("carrying") or c:GetAttribute("downed")==true then return end
        busy=true
        local n=combo
        playSeq("bat/swing_"..n,c)
        if n<3 then
            playClone(handle:FindFirstChild("Swing"),handle,math.random(50,150)/100)
            local trail=handle:FindFirstChild("Trail");if trail and trail:IsA("Trail") then trail.Enabled=true;task.delay(.5,function()if trail.Parent then trail.Enabled=false end end) end
            combo=n+1;task.delay(.4,function()busy=false end)
        else
            local h=Instance.new("Highlight");h.FillColor=Color3.fromRGB(227,219,219);h.OutlineColor3=Color3.new(0,0,0);h.FillTransparency=.25;h.Parent=c;Debris:AddItem(h,.4)
            task.delay(.7,function()
                if handle.Parent then
                    playClone(handle:FindFirstChild("Swing"),handle,math.random(50,150)/100)
                    local trail=handle:FindFirstChild("Trail");if trail and trail:IsA("Trail") then trail.Enabled=true;task.delay(.5,function()if trail.Parent then trail.Enabled=false end end) end
                end
            end)
            combo=1;task.delay(1.1,function()busy=false end)
        end
    end)
    connect(tool.Unequipped,function()
        playSeq("bat/unequip",player.Character);playClone(handle:FindFirstChild("Unequip"),handle);busy=false
    end)
end
local function scanWeapons()
    local bp=player:FindFirstChild("Backpack");if bp then for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") then wireOriginalWeapon(v) end end end
    local c=player.Character;if c then for _,v in ipairs(c:GetChildren()) do if v:IsA("Tool") then wireOriginalWeapon(v) end end end
end
scanWeapons()
local bp=player:WaitForChild("Backpack")
connect(bp.ChildAdded,function(v)task.defer(wireOriginalWeapon,v)end)
if player.Character then connect(player.Character.ChildAdded,function(v)task.defer(wireOriginalWeapon,v)end) end
connect(player.CharacterAdded,function(c)connect(c.ChildAdded,function(v)task.defer(wireOriginalWeapon,v)end)end)

setStatus("READY v2.2 | original info + music + emotes + weapon presentation + leaning")
return true
