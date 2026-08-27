-- FunCombat / Null Protocol client presentation loader
-- Server remains authoritative. This loader only imports native RBXM presentation
-- assets, forwards player input to server-owned remotes, and renders server events.
-- Target runtime: Xeno-compatible executors exposing writefile + game:GetObjects.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G

if ENV.__FUNCOMBAT_RUNTIME and type(ENV.__FUNCOMBAT_RUNTIME.destroy)=="function" then
    pcall(ENV.__FUNCOMBAT_RUNTIME.destroy)
end

local runtime = {connections={}, imported={}, dead=false}
ENV.__FUNCOMBAT_RUNTIME = runtime

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(runtime.connections,c)
    return c
end

local function track(inst)
    if inst then table.insert(runtime.imported,inst) end
    return inst
end

function runtime.destroy()
    if runtime.dead then return end
    runtime.dead=true
    for _,c in ipairs(runtime.connections) do pcall(function() c:Disconnect() end) end
    for _,v in ipairs(runtime.imported) do pcall(function() if v and v.Parent then v:Destroy() end end) end
    local g=pg:FindFirstChild("__FunCombatLoader")
    if g then pcall(function()g:Destroy()end) end
end

local statusGui=Instance.new("ScreenGui")
statusGui.Name="__FunCombatLoader"
statusGui.ResetOnSpawn=false
statusGui.IgnoreGuiInset=true
statusGui.DisplayOrder=1000000
statusGui.Parent=pg
track(statusGui)
local statusLabel=Instance.new("TextLabel")
statusLabel.AnchorPoint=Vector2.new(.5,0)
statusLabel.Position=UDim2.new(.5,0,0,8)
statusLabel.Size=UDim2.new(0,760,0,42)
statusLabel.BackgroundColor3=Color3.fromRGB(18,18,22)
statusLabel.BackgroundTransparency=.08
statusLabel.TextColor3=Color3.new(1,1,1)
statusLabel.Font=Enum.Font.Code
statusLabel.TextSize=15
statusLabel.TextWrapped=true
statusLabel.Text="FunCombat client: starting"
statusLabel.Parent=statusGui
local function status(s,bad)
    print("[FunCombat client] "..tostring(s))
    statusLabel.Text="FunCombat client: "..tostring(s)
    statusLabel.BackgroundColor3=bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,65,34)
end

local ALIAS={
    xaf2bb0d97d5d="Remotes",
    x4ebfd059b5e5="Hit",
    x40d6f4553ed6="PlaySound",
    x1fe87e6f17e8="ToggleParticles",
    xdc7fa05180f4="RagdollPlayer",
    x55e99a4dbb9d="Flash",
    x0d62dfb56e92="OnDeath",
    xc7720e51b46a="Ragdoll",
    x628ca2667e5d="RagdollForce",
    xe40a2326dbcf="TestAnimation",
    xad6326c1f61a="ChangeFunSpeed",
    xda7da817ec4a="ShowPrompt",
    x6b53699e19c1="IncreaseHitCount",
    x2a8e35ff91f9="ToggleResetting",
    xbb075d6bde39="DamageIndicator",
    x3050ec664e12="GetUp",
    xc013ac8c95d3="WallBounce",
    x2b267bb2c88a="Subtitles",
    x5988a13e5f9e="Emote",
    x1f40555480ee="ChangeAttacking",
    x1aed02c56da9="AwakenScreen",
    x8b438ed476b7="EquipWeapon",

    x06f340810381="RemoteEvents",
    xb53505bd95ca="Voted",
    x29bf1a4c4c94="VotingBegun",
    xe29bc60e6ec8="VotingEnded",
    x321747c0f450="awakenEvent",
    xede98b410a21="chatEvent",
    x4fbe0e9e0c97="weatherEvent",
    xbe2a334db2dd="UIRemote",

    x38e8915cf6c4="Prompts",
    xb085b6cb9c31="executePrompt",
    x569e44ba87ee="DefaultFun",
    xa5e54555633d="stopPrompt",
    xcaa35f67af02="carryPrompt",
    xc9eca057a6dd="dropPrompt",
    x90b04380a978="finishHoldPrompt",

    x3af6217d1a92="AttributeSystem",
    x967d386c24d6="SetInfo",
}

local function fixPrompt(v)
    if not v:IsA("ProximityPrompt") then return end
    if v.Name=="executePrompt" then v.ActionText="Execute";v.ObjectText="Victim"
    elseif v.Name=="carryPrompt" then v.ActionText="Carry";v.ObjectText="Victim"
    elseif v.Name=="DefaultFun" then v.ActionText="Fun";v.ObjectText="Victim"
    elseif v.Name=="dropPrompt" then v.ActionText="Drop"
    elseif v.Name=="stopPrompt" then v.ActionText="Stop"
    elseif v.Name=="finishHoldPrompt" then v.ActionText="Finish" end
end

local function translate(v)
    local n=ALIAS[v.Name]
    if n then pcall(function()v.Name=n end) end
    fixPrompt(v)
end

for _,v in ipairs(RS:GetDescendants()) do translate(v) end
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then translate(v) end end
connect(workspace.DescendantAdded,function(v) task.defer(function() translate(v) end) end)

local remotes=RS:WaitForChild("Remotes",15)
local remoteEvents=RS:WaitForChild("RemoteEvents",15)
local attrSystem=RS:WaitForChild("AttributeSystem",15)
if not remotes then error("server Remotes were not found; publish the server-only build first") end
if not attrSystem or not attrSystem:FindFirstChild("SetInfo") then error("server AttributeSystem/SetInfo missing") end

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/client/"
local CACHE="FunCombatClient"

if type(writefile)~="function" then
    error("This loader needs executor writefile() to cache native RBXM files")
end
pcall(function()
    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder(CACHE)) then
        makefolder(CACHE)
    end
end)

local paths={}
local function download(name)
    if paths[name] then return paths[name] end
    status("downloading "..name,false)
    local url=BASE..name.."?v="..tostring(math.floor(os.clock()*1000000))
    local ok,data=pcall(function() return game:HttpGet(url) end)
    if not ok or type(data)~="string" or #data<32 then
        error("download failed for "..name..": "..tostring(data))
    end
    if data:sub(1,7)=="version" or data:sub(1,1)=="{" or data:find("404: Not Found",1,true) then
        error("GitHub returned text instead of RBXM for "..name)
    end
    local path=CACHE.."/"..name
    writefile(path,data)
    task.wait(.15)
    paths[name]=path
    return path
end

local function getObjects(path)
    local attempts={path,"./"..path}
    if type(getcustomasset)=="function" then
        local ok,asset=pcall(getcustomasset,path)
        if ok and asset then table.insert(attempts,asset) end
    end
    local lastErr
    for _,candidate in ipairs(attempts) do
        local ok,res=pcall(function() return game:GetObjects(candidate) end)
        if ok then
            if typeof(res)=="Instance" then return {res} end
            if type(res)=="table" and #res>0 then return res end
        else
            lastErr=res
        end
    end
    error("executor could not deserialize local RBXM "..path.." | "..tostring(lastErr))
end

local packCache={}
local function import(name)
    if packCache[name] then
        local out={}
        for _,r in ipairs(packCache[name]) do table.insert(out,r:Clone()) end
        return out
    end
    local roots=getObjects(download(name))
    packCache[name]=roots
    return roots
end

local function mount(name,target,beforeParent)
    local roots=import(name)
    for _,r in ipairs(roots) do
        if beforeParent then beforeParent(r) end
        r:SetAttribute("__FunCombatImported",true)
        r.Parent=target
        track(r)
    end
    return roots
end

for _,name in ipairs({"AnimationManager","Rig","Weather","VFX","Sounds","NewMorphs","NewChanger","stats","society","offender","Animations"}) do
    local x=RS:FindFirstChild(name)
    if x and x:GetAttribute("__FunCombatImported") then pcall(function()x:Destroy()end) end
end

status("mounting presentation assets",false)
mount("VFX.rbxm",RS)
mount("Sounds.rbxm",RS)
mount("Weather.rbxm",RS)
mount("Rig.rbxm",RS)
mount("NewMorphs.rbxm",RS)
mount("NewChanger_ClientPresentation.rbxm",RS)
mount("Billboards.rbxm",RS)
mount("AnimationManager.rbxm",RS)
mount("Lighting.rbxm",Lighting)

local animations=RS:FindFirstChild("Animations")
if not animations then
    animations=Instance.new("Folder")
    animations.Name="Animations"
    animations:SetAttribute("__FunCombatImported",true)
    animations.Parent=RS
    track(animations)
end

local animFiles={male="Animations_male.rbxm",female="Animations_female.rbxm",bat="Animations_bat.rbxm",other="Animations_other.rbxm",Emotes="Animations_Emotes.rbxm"}
local animLoaded={}
local animLoading={}
local function findPath(root,path)
    local x=root
    for seg in string.gmatch(tostring(path or ""),"[^/]+") do
        x=x and x:FindFirstChild(seg)
    end
    return x
end
local function ensureAnimation(path)
    local found=findPath(animations,path)
    if found then return found end
    local first=tostring(path):match("^([^/]+)")
    local file=first and animFiles[first]
    if not file then return nil end
    if animLoading[file] then
        while animLoading[file] do task.wait() end
        return findPath(animations,path)
    end
    if not animLoaded[file] then
        animLoading[file]=true
        status("loading animation pack "..first,false)
        local ok,err=pcall(function() mount(file,animations) end)
        animLoading[file]=nil
        if not ok then error(err) end
        animLoaded[file]=true
    end
    return findPath(animations,path)
end

local active=setmetatable({},{__mode="k"})
local function jointsForPose(rig,pose,parentPose,out)
    local parentPart=parentPose and rig:FindFirstChild(parentPose.Name,true)
    local posePart=rig:FindFirstChild(pose.Name,true)
    if parentPart and posePart then
        for _,j in ipairs(rig:GetDescendants()) do
            if j:IsA("Motor6D") and ((j.Part0==parentPart and j.Part1==posePart) or (j.Part1==parentPart and j.Part0==posePart)) then
                out[j]=pose.CFrame
                break
            end
        end
    end
    for _,sub in ipairs(pose:GetSubPoses()) do jointsForPose(rig,sub,pose,out) end
end
local function frameMap(rig,kf)
    local out={}
    for _,pose in ipairs(kf:GetPoses()) do jointsForPose(rig,pose,nil,out) end
    return out
end
local function resetRig(rig)
    if not rig then return end
    for _,j in ipairs(rig:GetDescendants()) do if j:IsA("Motor6D") then pcall(function()j.Transform=CFrame.new()end) end end
end
local Anim={}
function Anim.PlayAnimation(seq,rig)
    if not seq or not seq:IsA("KeyframeSequence") or not rig then return nil end
    local frames=seq:GetKeyframes()
    table.sort(frames,function(a,b)return a.Time<b.Time end)
    if #frames==0 then return nil end
    local h={speed=1,dead=false,rig=rig}
    active[h]=true
    task.spawn(function()
        local start=os.clock();local duration=frames[#frames].Time
        while active[h] and not h.dead and rig.Parent do
            local t=(os.clock()-start)*h.speed
            if seq.Loop and duration>0 then t=t%duration elseif t>=duration then break end
            local a,b=frames[1],frames[#frames]
            for i=1,#frames-1 do
                if t>=frames[i].Time and t<=frames[i+1].Time then a,b=frames[i],frames[i+1];break end
            end
            local span=math.max(b.Time-a.Time,1/240)
            local alpha=math.clamp((t-a.Time)/span,0,1)
            local A=frameMap(rig,a);local B=frameMap(rig,b)
            for j,cf in pairs(A) do
                local to=B[j] or cf
                if j.Parent then j.Transform=cf:Lerp(to,alpha) end
            end
            RunService.RenderStepped:Wait()
        end
        active[h]=nil
        if not h.dead then resetRig(rig) end
    end)
    return h
end
function Anim.StopAnimation(h)
    if type(h)=="table" then h.dead=true;active[h]=nil;resetRig(h.rig) end
end
function Anim.ChangeAnimationSpeed(h,s)
    if type(h)=="table" then h.speed=(tonumber(s) or 50)/50 end
end
function Anim.StopCharacter(char)
    for h in pairs(active) do if h.rig==char then Anim.StopAnimation(h) end end
end

local function localSound(id,target,start,duration,speed)
    if not target or typeof(target)~="Instance" or not id then return end
    local s=Instance.new("Sound")
    s.SoundId=tostring(id)
    s.Parent=target
    if start then pcall(function()s.TimePosition=start end) end
    if speed then s.PlaybackSpeed=speed end
    s:Play()
    Debris:AddItem(s,duration or 12)
end
local function namedSound(name,target,start,duration,speed)
    local root=RS:FindFirstChild("Sounds")
    local src=root and root:FindFirstChild(tostring(name),true)
    if src and src:IsA("Sound") and target then
        local c=src:Clone();c.Parent=target
        if start then pcall(function()c.TimePosition=start end) end
        if speed then c.PlaybackSpeed=speed end
        c:Play();Debris:AddItem(c,duration or 12)
    end
end
local function flash(char,fill,outline,duration)
    if not char then return end
    local h=Instance.new("Highlight")
    h.FillColor=fill or Color3.new(1,1,1);h.OutlineColor=outline or Color3.new(0,0,0)
    h.FillTransparency=.25;h.Parent=char
    TweenService:Create(h,TweenInfo.new(duration or .5),{FillTransparency=1,OutlineTransparency=1}):Play()
    Debris:AddItem(h,duration or .5)
end
local function hitEffect(victim,name,parent)
    local vfx=RS:FindFirstChild("VFX");local hits=vfx and vfx:FindFirstChild("Hits")
    local dest=parent or (victim and (victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")))
    if not hits or not dest then return end
    local t=hits:FindFirstChild(tostring(name),true)
    if not t then return end
    local c=t:Clone();c.Parent=dest
    for _,e in ipairs(c:GetDescendants()) do
        if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end
    end
    Debris:AddItem(c,5)
end
local function awakenFx(char)
    local vfx=RS:FindFirstChild("VFX");if not vfx or not char then return end
    local torso=char:FindFirstChild("Torso")
    local circles=vfx:FindFirstChild("circles",true)
    if circles and torso then
        local q=circles:Clone();q.Parent=torso
        if q:IsA("ParticleEmitter") then q:Emit(35) end
        Debris:AddItem(q,5)
    end
end
local function juiceFx(target,n1,n2)
    if not target then return end
    local morph=target:FindFirstChild("boba") or target:FindFirstChild("pp")
    local juice=morph and morph:FindFirstChild("juice",true)
    if not juice then return end
    local blood=juice:FindFirstChild("Blood",true)
    if blood and blood:IsA("ParticleEmitter") then blood:Emit(n1 or 1) end
    local pe=juice:FindFirstChildWhichIsA("ParticleEmitter")
    if pe then pe:Emit(n2 or 1) end
end

local charTemplate
local charScriptsTemplate
local function revealCharacter(char)
    task.wait(1.15)
    if runtime.dead or not char.Parent then return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            if v.Name=="HumanoidRootPart" then v.Transparency=1 else v.Transparency=0 end
            pcall(function()v.LocalTransparencyModifier=0 end)
        elseif v:IsA("Decal") then
            v.Transparency=0
        end
    end
end

local function attachInfo(plr,char)
    local head=char:WaitForChild("Head",8);if not head then return end
    local old=head:FindFirstChild("__FunCombatInfo");if old then old:Destroy() end
    local b=Instance.new("BillboardGui")
    b.Name="__FunCombatInfo";b.AlwaysOnTop=true;b.Size=UDim2.new(0,210,0,46);b.StudsOffset=Vector3.new(0,2.15,0);b.Adornee=head;b.Parent=head
    local name=Instance.new("TextLabel");name.Name="NameText";name.BackgroundTransparency=1;name.Size=UDim2.new(1,0,.55,0);name.Font=Enum.Font.GothamBold;name.TextScaled=true;name.TextColor3=Color3.new(1,1,1);name.TextStrokeTransparency=.45;name.Text=plr.DisplayName;name.Parent=b
    local gender=Instance.new("TextLabel");gender.Name="GenderText";gender.BackgroundTransparency=1;gender.Position=UDim2.new(0,0,.55,0);gender.Size=UDim2.new(1,0,.38,0);gender.Font=Enum.Font.Gotham;gender.TextScaled=true;gender.TextColor3=Color3.fromRGB(220,220,230);gender.TextStrokeTransparency=.55;gender.Parent=b
    local function sync() gender.Text=tostring(plr:GetAttribute("Gender") or "") end
    sync();connect(plr:GetAttributeChangedSignal("Gender"),sync)
end

local function installCharacterScripts(char)
    revealCharacter(char)
    attachInfo(Players:GetPlayerFromCharacter(char) or player,char)
    local owner=Players:GetPlayerFromCharacter(char)
    if owner==player and charScriptsTemplate then
        for _,src in ipairs(charScriptsTemplate:GetChildren()) do
            if not char:FindFirstChild(src.Name) then
                local c=src:Clone();c.Parent=char;track(c)
            end
        end
    end
end

local function hookPlayer(plr)
    if plr.Character then task.spawn(installCharacterScripts,plr.Character) end
    connect(plr.CharacterAdded,function(c) task.spawn(installCharacterScripts,c) end)
end
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
connect(Players.PlayerAdded,hookPlayer)

status("loading GUI",false)
local guiRoots=import("StarterGui.rbxm")
for _,root in ipairs(guiRoots) do
    for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("LocalScript") and d:FindFirstAncestorWhichIsA("Tool") then d.Disabled=true end
    end
    root:SetAttribute("__FunCombatImported",true)
    root.Parent=pg
    track(root)
end

status("loading player scripts",false)
local starterRoots=import("StarterPlayer.rbxm")
for _,root in ipairs(starterRoots) do
    if root.Name=="StarterPlayerScripts" then
        local ps=player:WaitForChild("PlayerScripts")
        for _,c in ipairs(root:GetChildren()) do c.Parent=ps;track(c) end
        root:Destroy()
    elseif root.Name=="StarterCharacterScripts" then
        charScriptsTemplate=root
        if player.Character then task.spawn(installCharacterScripts,player.Character) end
    elseif root:IsA("Model") and root.Name=="StarterCharacter" then
        charTemplate=root
    end
end

local hitRemote=remotes:WaitForChild("Hit")
local equipRemote=remotes:WaitForChild("EquipWeapon")
local bus=remotes:WaitForChild("TestAnimation")
local weaponMenu=pg:FindFirstChild("weapon")
local weaponTemplates={}
if weaponMenu then
    for _,v in ipairs(weaponMenu:GetDescendants()) do
        if v:IsA("Tool") then weaponTemplates[v.Name]=v end
    end
end

local weaponConns=setmetatable({},{__mode="k"})
local function sanitizeTool(tool)
    for _,d in ipairs(tool:GetDescendants()) do
        if d:IsA("LocalScript") or d:IsA("Script") then d.Disabled=true end
    end
    tool:SetAttribute("__FunCombatVisualWeapon",true)
end
local function clearVisualWeapon(char)
    if not char then return end
    for _,v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then pcall(function()v:Destroy()end) end
    end
    local bp=player:FindFirstChild("Backpack")
    if bp then
        for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then pcall(function()v:Destroy()end) end end
    end
end
local function wireAttack(tool)
    local busy=false;local combo=1;local last=0
    connect(tool.Activated,function()
        if busy then return end
        local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then return end
        if char:GetAttribute("downed")==true or char:FindFirstChild("stun") or char:GetAttribute("carrying")==true then return end
        if os.clock()-last>2.2 then combo=1 end
        local move=(combo==1 and "SWING_1") or (combo==2 and "SWING_2") or "BIG_SWING"
        last=os.clock();combo=combo%3+1;busy=true
        hitRemote:FireServer(move)
        task.delay(move=="BIG_SWING" and 1 or .36,function()busy=false end)
    end)
end
local function presentWeapon(plr,name)
    local char=plr.Character;if not char then return end
    if plr==player then clearVisualWeapon(char) else
        for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") and v:GetAttribute("__FunCombatVisualWeapon") then v:Destroy() end end
    end
    if not name then return end
    local t=weaponTemplates[tostring(name)]
    if not t then warn("[FunCombat client] weapon template missing: "..tostring(name));return end
    local clone=t:Clone();sanitizeTool(clone)
    local hum=char:FindFirstChildOfClass("Humanoid")
    if plr==player then
        local bp=player:WaitForChild("Backpack")
        clone.Parent=bp;track(clone);wireAttack(clone)
        if hum then task.defer(function()pcall(function()hum:EquipTool(clone)end)end) end
    else
        clone.Parent=char;track(clone)
        if hum then task.defer(function()pcall(function()hum:EquipTool(clone)end)end) end
    end
    task.spawn(function()
        local seq=ensureAnimation("bat/flourish")
        if seq and char.Parent then Anim.PlayAnimation(seq,char) end
    end)
end

for _,p in ipairs(Players:GetPlayers()) do
    task.defer(function()presentWeapon(p,p:GetAttribute("EquippedWeapon"))end)
end

local handles={}
local changer
pcall(function() changer=require(RS:WaitForChild("NewChanger")) end)
connect(bus.OnClientEvent,function(op,...)
    local a={...}
    if op=="A" then
        local id,path,char=a[1],a[2],a[3]
        task.spawn(function()
            local seq=ensureAnimation(path)
            if seq and char and char.Parent then
                if handles[id] then Anim.StopAnimation(handles[id]) end
                handles[id]=Anim.PlayAnimation(seq,char)
            else
                warn("[FunCombat client] animation not found: "..tostring(path))
            end
        end)
    elseif op=="AS" then
        local h=handles[a[1]];if h then Anim.StopAnimation(h);handles[a[1]]=nil end
    elseif op=="AV" then
        local h=handles[a[1]];if h then Anim.ChangeAnimationSpeed(h,a[2]) end
    elseif op=="ASTOPCHAR" then
        Anim.StopCharacter(a[1])
    elseif op=="S" then
        localSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="SN" then
        namedSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="HS" then
        namedSound(a[1],a[2] and (a[2]:FindFirstChild("HumanoidRootPart") or a[2]))
    elseif op=="F" then
        flash(a[1],a[2],a[3],a[4])
    elseif op=="H" then
        hitEffect(a[1],a[2],a[3])
    elseif op=="W" then
        awakenFx(a[1])
    elseif op=="P" then
        juiceFx(a[1],a[2],a[3])
    elseif op=="M+" then
        if changer then pcall(function()changer:loadMorph(a[1],a[2])end) end
    elseif op=="M-" then
        if changer then pcall(function()changer:clearMorph(a[1],a[2])end) end
    elseif op=="EQ" then
        local plr,name=a[1],a[2]
        if typeof(plr)=="Instance" and plr:IsA("Player") then presentWeapon(plr,name) end
    end
end)

for _,p in ipairs(Players:GetPlayers()) do
    connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()
        task.defer(function()presentWeapon(p,p:GetAttribute("EquippedWeapon"))end)
    end)
end
connect(Players.PlayerAdded,function(p)
    connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()
        task.defer(function()presentWeapon(p,p:GetAttribute("EquippedWeapon"))end)
    end)
end)

status("READY | native RBXM client mounted",false)
return true
