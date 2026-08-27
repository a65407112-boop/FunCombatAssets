-- Null Protocol stable loader v4
-- Keeps gameplay server-authoritative. Client only reconstructs presentation
-- when the server requests it through the visual bus.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- The pinned loader is our known-good serializer repair/bootstrap layer.
local BASE_COMMIT = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/5129021c5eccb630a12ffeba79742bb393c5e569/"
local src = game:HttpGet(BASE_COMMIT .. "loader.lua?cb=" .. tostring(os.clock()))

-- Fix the old chunked-mount replacement. Use a function so '%' is never
-- interpreted as a gsub capture reference.
local oldChunk = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%%200==0 then task.wait() end",
        2
    )]]
local newChunk = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        function()
            return "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%25==0 then task.wait() end"
        end,
        2
    )]]
local p = src:find(oldChunk, 1, true)
if not p then error("Null Protocol hotfix: chunk patch point not found") end
src = src:sub(1,p-1) .. newChunk .. src:sub(p+#oldChunk)

-- Disable the legacy timed rig load completely. rig_assets is now loaded by
-- the core only when the SERVER sends M+ on the visual bus.
local oldRigStart = [[task.spawn(function()
    task.wait(2)
    print("[Null Protocol] loading rig_assets.lua")]]
local newRigStart = [[task.spawn(function()
    while not (((getgenv and getgenv()) or _G).__NULL_LEGACY_RIG_NEVER) do
        task.wait(3600)
    end
    print("[Null Protocol] legacy rig loader disabled")]]
local rp = src:find(oldRigStart,1,true)
if not rp then error("Null Protocol hotfix: legacy rig-load patch point not found") end
src = src:sub(1,rp-1) .. newRigStart .. src:sub(rp+#oldRigStart)

-- Do not load animation data because somebody clicked an Emotes GUI button.
-- Animation data must be requested by the server's A visual-bus opcode.
src = src:gsub('local emotes=pg:FindFirstChild%("Emotes"%)','local emotes=nil -- animations are server-event driven',1)

-- Inject architecture fixes into the base loader's patchCore(). This code edits
-- core.lua after its serializer repairs, immediately before it is compiled.
local patchEnd = "    return src\nend\n\nlocal ok,result=xpcall"
local injection = [=[
    -- v4: Do NOT hide/replace the live character automatically. The server rig
    -- remains the gameplay/physics authority. Starting presentation is plain R6
    -- Blocky; morph visuals are only applied when the server sends M+.
    do
        local a=src:find("local function attachShell(c)",1,true)
        local b=a and src:find("-- Execute external LocalScripts after the tree exists.",a,true)
        if a and b then
            src=src:sub(1,a-1).."local function attachShell(c) return end\n\n"..src:sub(b)
        end
    end

    -- v4: install lazy, SERVER-DRIVEN heavy asset loaders in core.lua.
    local busMarker='if bus then bus.OnClientEvent:Connect(function(op,...)'
    local bp=src:find(busMarker,1,true)
    if bp then
        local helpers=[[
local __rtRigLoaded=false
local __rtRigLoading=false
local __rtAnimLoaded={}

local function ensureRigAssets()
    if __rtRigLoaded then return true end
    if __rtRigLoading then
        while __rtRigLoading do task.wait() end
        return __rtRigLoaded
    end
    __rtRigLoading=true
    print("[Null Protocol] server requested morph assets")
    local ok,pack=pcall(get,"data/rig_assets.lua")
    if ok and pack then
        mount(pack,RS)
        __rtRigLoaded=true
        print("[Null Protocol] rig_assets mounted on M+")
    else
        warn("[Null Protocol] rig_assets M+ load failed: "..tostring(pack))
    end
    __rtRigLoading=false
    return __rtRigLoaded
end

local function ensureAnimation(path)
    local root=RS:FindFirstChild("Animations")
    if not root then root=Instance.new("Folder");root.Name="Animations";root.Parent=RS end
    local existing=findPath(root,path)
    if existing then return existing end

    local low=string.lower(tostring(path or ""))
    local preferred
    if low:find("female",1,true) then preferred="anim_female.lua"
    elseif low:find("emote",1,true) then preferred="anim_emotes.lua"
    elseif low:find("bat",1,true) then preferred="anim_bat.lua"
    elseif low:find("male",1,true) then preferred="anim_male.lua"
    else preferred="anim_other.lua" end

    local order={preferred,"anim_male.lua","anim_female.lua","anim_bat.lua","anim_other.lua","anim_emotes.lua"}
    local seen={}
    for _,file in ipairs(order) do
        if not seen[file] then
            seen[file]=true
            if not __rtAnimLoaded[file] then
                print("[Null Protocol] server requested animation pack "..file)
                local ok,pack=pcall(get,"data/"..file)
                if ok and pack then
                    mount(pack,root)
                    __rtAnimLoaded[file]=true
                else
                    warn("[Null Protocol] animation pack failed "..file..": "..tostring(pack))
                end
            end
            local seq=findPath(root,path)
            if seq then return seq end
        end
    end
    return nil
end
]]
        src=src:sub(1,bp-1)..helpers..src:sub(bp)
    end

    local oldA='if op=="A" and AnimMgr then local id,path,c=a[1],a[2],a[3]; local seq=findPath(animRoot,path); if seq then animHandles[id]=AnimMgr.PlayAnimation(seq,c) end'
    local newA='if op=="A" and AnimMgr then local id,path,c=a[1],a[2],a[3]; local seq=ensureAnimation(path); if seq then animHandles[id]=AnimMgr.PlayAnimation(seq,c) else warn("[Null Protocol] animation not found: "..tostring(path)) end'
    local ap=src:find(oldA,1,true)
    if ap then src=src:sub(1,ap-1)..newA..src:sub(ap+#oldA) end

    local oldM='elseif op=="M+" then local m=RS:FindFirstChild("NewChanger"); if m then local mm=runtimeRequire(m); pcall(function()mm:loadMorph(a[1],a[2])end) end'
    local newM='elseif op=="M+" then if ensureRigAssets() then local m=RS:FindFirstChild("NewChanger"); if m then local mm=runtimeRequire(m); local okMorph,morphErr=pcall(function()mm:loadMorph(a[1],a[2])end); if not okMorph then warn("[Null Protocol] M+ morph failed: "..tostring(morphErr)) end end end'
    local mp=src:find(oldM,1,true)
    if mp then src=src:sub(1,mp-1)..newM..src:sub(mp+#oldM) end

    return src
end

local ok,result=xpcall]=]
local ep=src:find(patchEnd,1,true)
if not ep then error("Null Protocol hotfix: patchCore end not found") end
src=src:sub(1,ep-1)..injection..src:sub(ep+#patchEnd)

local fn,err=loadstring(src,"NullProtocolFixedLoaderV4")
if not fn then error("Null Protocol v4 loader compile failed: "..tostring(err)) end
local result=fn()

-- Keep the initial character visually sane. Never delete accessories, never hide
-- body parts, never touch gameplay joints. If the server gave us R6, remove only
-- local CharacterMesh package shaping so the base body is classic Blocky.
local function restoreBlocky(c)
    if not c then return end
    local old=c:FindFirstChild("__rt_shell")
    if old then pcall(function() old:Destroy() end) end

    local hum=c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.RigType~=Enum.HumanoidRigType.R6 then
        warn("[Null Protocol] server character is not R6; got "..tostring(hum.RigType))
        return
    end

    for _,name in ipairs({"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg","HumanoidRootPart"}) do
        local part=c:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            pcall(function() part.LocalTransparencyModifier=0 end)
        end
    end
    for _,v in ipairs(c:GetChildren()) do
        if v:IsA("CharacterMesh") then pcall(function() v:Destroy() end) end
    end
end
if plr.Character then task.defer(restoreBlocky,plr.Character) end
plr.CharacterAdded:Connect(function(c) task.wait(); restoreBlocky(c) end)

-- Reliable Gender fallback. The exported controller is still allowed to run,
-- but this does not depend on its internal object names or its 0.1-second race.
task.spawn(function()
    local pg=plr:WaitForChild("PlayerGui",10)
    if not pg then return end
    local gender=pg:WaitForChild("Gender",10)
    if not gender then return end

    local attr="qe8be68a176690a76"
    if plr:GetAttribute(attr) then
        gender.Enabled=false
        return
    end

    gender.Enabled=true
    local handled=false
    local function findSetInfo()
        local sys=RS:FindFirstChild("AttributeSystem")
        local e=sys and sys:FindFirstChild("SetInfo")
        if e and e:IsA("RemoteEvent") then return e end
        for _,v in ipairs(RS:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name=="SetInfo" then return v end
        end
    end

    local function choose(button)
        if handled then return end
        handled=true
        gender.Enabled=false
        local value=tostring(button.Text)
        local ev=findSetInfo()
        if ev then
            local okFire,fireErr=pcall(function() ev:FireServer(attr,value) end)
            if not okFire then warn("[Null Protocol] Gender SetInfo failed: "..tostring(fireErr)) end
        else
            warn("[Null Protocol] Gender SetInfo RemoteEvent not found")
        end
        print("[Null Protocol] Gender selected: "..value)
    end

    local count=0
    for _,v in ipairs(gender:GetDescendants()) do
        if v:IsA("TextButton") then
            local text=string.lower((v.Text or ""):gsub("%s+",""))
            if text=="male" or text=="female" or text=="fembxy" then
                count+=1
                v.Activated:Connect(function() choose(v) end)
                v.MouseButton1Click:Connect(function() choose(v) end)
            end
        end
    end
    if count==0 then warn("[Null Protocol] Gender fallback found 0 choice buttons") end
end)

return result
