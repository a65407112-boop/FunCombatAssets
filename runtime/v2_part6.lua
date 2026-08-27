    local opener=weaponOpen:FindFirstChildWhichIsA("GuiButton",true)
    if not nativeRan then bindOnce(opener,"__FCWeaponOpen",function()weaponGui.Enabled=not weaponGui.Enabled end) end
    for _,b in ipairs(weaponGui:GetDescendants()) do
        if b:IsA("TextButton") then
            local t=b:FindFirstChildWhichIsA("Tool",true)
            if t and not nativeRan then bindOnce(b,"__FCWeaponPick",function()equipRemote:FireServer(t.Name)end) end
        end
    end
end

local hitGui=pg:FindFirstChild("HitboxToggle")
if hitGui then
    local toggle=hitGui:FindFirstChild("Toggle")
    local btn=hitGui:FindFirstChildWhichIsA("GuiButton",true)
    if toggle and toggle:IsA("BoolValue") then
        local native=hitGui:FindFirstChildWhichIsA("LocalScript",true)
        local nativeRan=native and native:GetAttribute("__FCRan")
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

-- Map voting fallback.
local voteGui=pg:FindFirstChild("MapVoteGui")
if voteGui and remoteEvents then
    local frame=voteGui:FindFirstChild("MapVoteFrame")
    local voting=voteGui:FindFirstChild("VotingClient")
    local template=voting and voting:FindFirstChild("MapFrame")
    if frame and template then
        local nativeRan=voting:IsA("LocalScript") and voting:GetAttribute("__FCRan")
        local container=frame:FindFirstChild("MapsContainer")
        if not nativeRan then connect(remoteEvents:WaitForChild("VotingBegun").OnClientEvent,function(maps)
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
        end) end
    end
end

-- Weapon visuals are cloned only after the server approves EquippedWeapon.
local hitRemote=remotes:WaitForChild("Hit")
local bus=remotes:WaitForChild("TestAnimation")
local weaponTemplates={}
if weaponGui then for _,v in ipairs(weaponGui:GetDescendants()) do if v:IsA("Tool") then weaponTemplates[v.Name]=v end end end
local function sanitizeTool(tool)
    for _,d in ipairs(tool:GetDescendants()) do if d:IsA("LocalScript") or d:IsA("Script") then pcall(function()d.Disabled=true end) end end
    tool:SetAttribute("__FunCombatVisualWeapon",true)
end
local function clearVisualWeapon(plr)
    local c=plr.Character;if c then for _,v in ipairs(c:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then v:Destroy() end end end
    if plr==player then local bp=player:FindFirstChild("Backpack");if bp then for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then v:Destroy() end end end end
end
local function wireAttack(tool)
    local busy=false;local combo=1;local last=0
    connect(tool.Activated,function()
        if busy then return end
        local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
        if not c or not h or h.Health<=0 or c:GetAttribute("downed")==true or c:FindFirstChild("stun") then return end
        if os.clock()-last>2.2 then combo=1 end
        local move=(combo==1 and "SWING_1") or (combo==2 and "SWING_2") or "BIG_SWING"
        last=os.clock();combo=combo%3+1;busy=true;hitRemote:FireServer(move)
        task.delay(move=="BIG_SWING" and 1 or .36,function()busy=false end)
    end)
end
local function presentWeapon(plr,name)
    clearVisualWeapon(plr);if not name then return end
    local t=weaponTemplates[tostring(name)];local c=plr.Character;if not t or not c then return end
    local clone=t:Clone();sanitizeTool(clone);track(clone)
    local h=c:FindFirstChildOfClass("Humanoid")
    if plr==player then clone.Parent=player:WaitForChild("Backpack");wireAttack(clone);if h then task.defer(function()pcall(function()h:EquipTool(clone)end)end) end
    else clone.Parent=c;if h then task.defer(function()pcall(function()h:EquipTool(clone)end)end) end end
