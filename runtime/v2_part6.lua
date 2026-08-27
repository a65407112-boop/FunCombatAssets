local equipRemote=remotes:WaitForChild("EquipWeapon")
local weaponGui=pg:FindFirstChild("weapon")
local weaponOpen=pg:FindFirstChild("weaponGui")
if weaponGui and weaponOpen then
    local native=weaponOpen:FindFirstChildWhichIsA("LocalScript",true);local nativeRan=native and native:GetAttribute("__FCRan")
    local opener=weaponOpen:FindFirstChildWhichIsA("GuiButton",true)
    if not nativeRan then
        bindOnce(opener,"__FCWeaponOpen",function()weaponGui.Enabled=not weaponGui.Enabled end)
        for _,b in ipairs(weaponGui:GetDescendants()) do
            if b:IsA("TextButton") then
                local t=b:FindFirstChildWhichIsA("Tool",true)
                if t then bindOnce(b,"__FCWeaponPick",function()equipRemote:FireServer(t.Name)end) end
            end
        end
    end
    connect(player:GetAttributeChangedSignal("EquippedWeapon"),function()if player:GetAttribute("EquippedWeapon") then weaponGui.Enabled=false end end)
end

local hitGui=pg:FindFirstChild("HitboxToggle")
if hitGui then
    local toggle=hitGui:FindFirstChild("Toggle");local btn=hitGui:FindFirstChildWhichIsA("GuiButton",true)
    if toggle and toggle:IsA("BoolValue") then
        local native=hitGui:FindFirstChildWhichIsA("LocalScript",true);local nativeRan=native and native:GetAttribute("__FCRan")
        if not nativeRan then bindOnce(btn,"__FCHitbox",function()
            toggle.Value=not toggle.Value
            local label=btn and btn:FindFirstChildWhichIsA("TextLabel",true);if label then label.Text=toggle.Value and "Hitboxes: On" or "Hitboxes: Off" end
        end) end
    end
end

local getUpRemote=remotes:WaitForChild("GetUp")
local mobile=pg:FindFirstChild("mobileButtons")
if mobile then
    local g=pg:FindFirstChild("getUp");local native=g and g:FindFirstChildWhichIsA("LocalScript",true);local nativeRan=native and native:GetAttribute("__FCRan")
    local b=mobile:FindFirstChild("GetUp");if not nativeRan then bindOnce(b,"__FCGetUp",function()getUpRemote:FireServer()end) end
end

local voteGui=pg:FindFirstChild("MapVoteGui")
if voteGui and remoteEvents then
    local frame=voteGui:FindFirstChild("MapVoteFrame");local voting=voteGui:FindFirstChild("VotingClient");local template=voting and voting:FindFirstChild("MapFrame")
    if frame and template then
        local nativeRan=voting:IsA("LocalScript") and voting:GetAttribute("__FCRan");local container=frame:FindFirstChild("MapsContainer")
        if not nativeRan then
            connect(remoteEvents:WaitForChild("VotingBegun").OnClientEvent,function(maps)
                if not container then return end
                for _,c in ipairs(container:GetChildren()) do if c:IsA(template.ClassName) then c:Destroy() end end
                for _,map in ipairs(maps or {}) do
                    local f=template:Clone();f.Name=map.Name
                    if f:FindFirstChild("MapName") then f.MapName.Text=map.Name end
                    if f:FindFirstChild("NumVotes") then f.NumVotes.Text="Votes: 0" end
                    local vb=f:FindFirstChild("VoteButton");if vb then connect(vb.Activated,function()remoteEvents.Voted:FireServer(map.Name)end) end
                    f.Parent=container
                end
                frame.Visible=true
            end)
            connect(remoteEvents:WaitForChild("VotingEnded").OnClientEvent,function()frame.Visible=false end)
            connect(remoteEvents:WaitForChild("Voted").OnClientEvent,function(plrVotes)
                if not container then return end
                local votes={};for _,vote in pairs(plrVotes or {}) do votes[vote]=(votes[vote] or 0)+1 end
                for _,f in ipairs(container:GetChildren()) do if f:FindFirstChild("NumVotes") then f.NumVotes.Text="Votes: "..tostring(votes[f.Name] or 0) end end
            end)
        end
    end
end

local hitRemote=remotes:WaitForChild("Hit")
local bus=remotes:WaitForChild("TestAnimation")
local weaponTemplates={}
if weaponGui then for _,v in ipairs(weaponGui:GetDescendants()) do if v:IsA("Tool") then weaponTemplates[v.Name]=v end end end
local visualWeapons=setmetatable({},{__mode="k"})
local weaponStates=setmetatable({},{__mode="k"})

local function toolSound(tool,name,target,speed)
    if not tool then return end
    local src=tool:FindFirstChild(name,true);if not src or not src:IsA("Sound") then return end
    local s=src:Clone();s.Parent=target or tool:FindFirstChild("Handle") or workspace.CurrentCamera
    if speed then s.PlaybackSpeed=speed end;s.TimePosition=0;s:Play();Debris:AddItem(s,math.max(4,s.TimeLength+1))
end
local function toolTrail(tool,on,seconds)
    local handle=tool and tool:FindFirstChild("Handle");local tr=handle and handle:FindFirstChild("Trail")
    if tr and tr:IsA("Trail") then tr.Enabled=on;if on and seconds then task.delay(seconds,function()if tr.Parent then tr.Enabled=false end end) end end
end
local function convertGrip(char,tool)
    local arm=char and char:FindFirstChild("Right Arm");local handle=tool and tool:FindFirstChild("Handle");if not arm or not handle then return end
    local old=arm:FindFirstChild("RightGrip")
    if old and old.Part0 and old.Part1 then
        if old:IsA("Motor6D") then return old end
        local n=Instance.new("Motor6D");n.Name="RightGrip";n.Part0=old.Part0;n.Part1=old.Part1;n.C0=old.C0;n.C1=old.C1;n.Parent=arm;old:Destroy();return n
    end
    local n=Instance.new("Motor6D");n.Name="RightGrip";n.Part0=arm;n.Part1=handle
    n.C0=CFrame.new(0,-1,0)*(tool.Grip or CFrame.new());n.Parent=arm;return n
end
local function validLocalWeaponState()
    local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    if not c or not h or h.Health<=0 or c:GetAttribute("downed")==true or c:FindFirstChild("stun") then return end
    local carrying=c:GetAttribute("carrying");if carrying and carrying~=false and carrying~="nill" then return end
    return c,h
end
local function sanitizeTool(tool)
    for _,d in ipairs(tool:GetDescendants()) do if d:IsA("LocalScript") or d:IsA("Script") then pcall(function()d.Disabled=true end) end end
    tool:SetAttribute("__FunCombatVisualWeapon",true)
end
local function clearVisualWeapon(plr)
    local old=visualWeapons[plr];visualWeapons[plr]=nil
    if old then pcall(function()old:Destroy()end) end
    weaponStates[plr]=nil
    if plr==player then
        local bp=player:FindFirstChild("Backpack");if bp then for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then v:Destroy() end end end
        local c=player.Character;if c then for _,v in ipairs(c:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then v:Destroy() end end end
    end
end

local function wireLocalWeapon(tool,state)
    local mouse=player:GetMouse()
    local function equip()
        state.equipped=true;state.ready=false;mouse.Icon="rbxasset://textures/GunCursor.png"
        local c=player.Character;if c then task.delay(.08,function()if tool.Parent and c.Parent then convertGrip(c,tool) end end) end
        toolSound(tool,"Equip")
        task.spawn(function()
            local seq=ensureAnimation("bat/flourish");if seq and c and c.Parent then Anim.PlayAnimation(seq,c) end
        end)
        local token=(state.eqToken or 0)+1;state.eqToken=token
        task.delay(1.5,function()if state.equipped and state.eqToken==token then toolSound(tool,"Equip2") end end)
        task.delay(1.75,function()if state.equipped and state.eqToken==token then state.ready=true end end)
    end
    local function unequip()
        state.equipped=false;state.ready=false;state.eqToken=(state.eqToken or 0)+1;mouse.Icon=""
        local c=player.Character;toolSound(tool,"Unequip")
        task.spawn(function()local seq=ensureAnimation("bat/unequip");if seq and c and c.Parent then Anim.PlayAnimation(seq,c) end end)
    end
    connect(tool.Equipped,equip);connect(tool.Unequipped,unequip)
    connect(tool.Activated,function()
        if not state.equipped or not state.ready or state.busy then return end
        local c=validLocalWeaponState();if not c then return end
        local combo=state.combo or 1;local move=combo==1 and "SWING_1" or combo==2 and "SWING_2" or "BIG_SWING"
        state.busy=true;state.pending=move;hitRemote:FireServer(move)
        task.delay(move=="BIG_SWING" and 1.12 or .42,function()if state.pending==move then state.pending=nil end;state.busy=false end)
    end)
    local function requestDash()
        if not state.equipped or state.dashBusy then return end
        local c=validLocalWeaponState();if not c then return end
        state.dashBusy=true;hitRemote:FireServer("DASH");task.delay(1.35,function()state.dashBusy=false end)
    end
    connect(UIS.InputBegan,function(input,gp)if not gp and input.KeyCode==Enum.KeyCode.Q then requestDash() end end)
    local dashButton=mobile and mobile:FindFirstChild("Dash",true);if dashButton and dashButton:IsA("GuiButton") then bindOnce(dashButton,"__FCDash",requestDash) end
end

local function presentWeapon(plr,name)
    clearVisualWeapon(plr);if not name then return end
    local template=weaponTemplates[tostring(name)];local char=plr.Character;if not template or not char then return end
    local tool=template:Clone();sanitizeTool(tool);track(tool);visualWeapons[plr]=tool
    local state={combo=1,busy=false,dashBusy=false,equipped=false,ready=false};weaponStates[plr]=state
    local hum=char:FindFirstChildOfClass("Humanoid")
    if plr==player then
        tool.Parent=player:WaitForChild("Backpack");wireLocalWeapon(tool,state)
        if hum then task.defer(function()pcall(function()hum:EquipTool(tool)end)end) end
    else
        tool.Parent=char
        task.delay(.05,function()if tool.Parent and char.Parent then convertGrip(char,tool) end end)
    end
end

-- These are presentation of SERVER-ACCEPTED actions, not local hit decisions.
local function weaponAction(plr,move)
    local tool=visualWeapons[plr];if not tool then return end
    local state=weaponStates[plr]
    if plr==player and state then
        state.pending=nil;state.combo=(move=="SWING_1" and 2) or (move=="SWING_2" and 3) or 1
    end
    if move=="BIG_SWING" then
        local char=plr.Character;if char then
            local hi=Instance.new("Highlight");hi.FillColor=Color3.new(1,1,1);hi.OutlineColor=Color3.new(0,0,0);hi.FillTransparency=0;hi.OutlineTransparency=0;hi.Parent=char
            TweenService:Create(hi,TweenInfo.new(.4),{FillTransparency=1,OutlineTransparency=1}):Play();Debris:AddItem(hi,.45)
        end
        task.delay(.7,function()if tool.Parent then toolSound(tool,"Swing",nil,math.random(-50,50)*.01+1);toolTrail(tool,true,.5) end end)
    else
        toolSound(tool,"Swing",nil,math.random(-50,50)*.01+1);toolTrail(tool,true,.5)
    end
end

local function dashVisual(plr,inAir,awakened)
    local char=plr.Character;if not char then return end
    local tool=visualWeapons[plr];local root=char:FindFirstChild("HumanoidRootPart")
    if tool then toolSound(tool,"DashSound",root);toolSound(tool,awakened and "awakened" or "normal",root) end
    local col=awakened and Color3.fromRGB(255,0,0) or Color3.fromRGB(255,255,255)
    local hi=Instance.new("Highlight");hi.DepthMode=Enum.HighlightDepthMode.Occluded;hi.FillTransparency=.7;hi.OutlineTransparency=0;hi.FillColor=col;hi.OutlineColor=col;hi.Parent=char
    TweenService:Create(hi,TweenInfo.new(.4,Enum.EasingStyle.Sine,Enum.EasingDirection.In),{OutlineTransparency=1}):Play();Debris:AddItem(hi,.4)
    local vfx=RS:FindFirstChild("VFX");local limbs=vfx and vfx:FindFirstChild("dash_limbs");local smoke=vfx and vfx:FindFirstChild("dash_smoke")
    if limbs then
        for _,ln in ipairs({"Left Arm","Right Arm","Right Leg","Left Leg"}) do
            local part=char:FindFirstChild(ln)
            if part then
                if not part:FindFirstChild("dash0") then
                    local bundle=limbs:Clone();for _,q in ipairs(bundle:GetChildren()) do q.Parent=part end;bundle:Destroy()
                end
                for _,q in ipairs(part:GetChildren()) do if q:IsA("Trail") and q.Name:find("dash") then q.Enabled=true;task.delay(.3,function()if q.Parent then q.Enabled=false end end) end end
            end
        end
    end
    if not inAir and root and smoke then
        if not root:FindFirstChild("dust") then local d=smoke:FindFirstChild("dust");if d then d=d:Clone();d.Parent=root end end
        local d=root:FindFirstChild("dust");if d then for _,q in ipairs(d:GetChildren()) do if q:IsA("ParticleEmitter") then q.Enabled=true;task.delay(.3,function()if q.Parent then q.Enabled=false end end) end end end
    end
end

for _,p in ipairs(Players:GetPlayers()) do
    task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"))
    connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"))end)
end
connect(Players.PlayerAdded,function(p)connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"))end)end)

-- Server bus handling continues in part 7.
