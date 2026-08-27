return function(BASE)
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local function get(path)
    local s=game:HttpGet(BASE..path)
    local f,e=loadstring(s,"@"..path); if not f then error(e) end
    return f()
end
local names=get("data/names.lua")
local aliases=names.aliases

-- Translate opaque replicated names locally. Server object identity is unchanged.
local function translateTree(root)
    for _,v in ipairs(root:GetDescendants()) do
        local n=aliases[v.Name]; if n then pcall(function() v.Name=n end) end
        if v:IsA("ProximityPrompt") then
            local t=names.promptText[v.ActionText]; if t then v.ActionText=t end
            local o=names.promptText[v.ObjectText]; if o then v.ObjectText=o end
        end
    end
end
translateTree(RS); translateTree(workspace)
workspace.DescendantAdded:Connect(function(v)
    task.defer(function()
        local n=aliases[v.Name]; if n then pcall(function() v.Name=n end) end
        if v:IsA("ProximityPrompt") then
            local t=names.promptText[v.ActionText]; if t then v.ActionText=t end
            local o=names.promptText[v.ObjectText]; if o then v.ObjectText=o end
        end
    end)
end)

local moduleCache=setmetatable({},{__mode="k"})
local sourceByInst=setmetatable({},{__mode="k"})
local nativeRequire=require
local function runtimeRequire(mod)
    if sourceByInst[mod] then
        if moduleCache[mod]~=nil then return moduleCache[mod] end
        local env=setmetatable({script=mod},{__index=getfenv and getfenv() or _G})
        env.require=runtimeRequire
        local fn,er=loadstring(sourceByInst[mod],"="..mod:GetFullName()); if not fn then error(er) end
        if setfenv then setfenv(fn,env) end
        local val=fn(); moduleCache[mod]=val; return val
    end
    return nativeRequire(mod)
end

local createdRoots={}
local function mount(pack,target)
    local by={}
    local pendingRefs={}
    for _,n in ipairs(pack.nodes) do
        local ok,obj=pcall(Instance.new,n.c)
        if ok and obj then
            obj.Name=n.n; by[n.id]=obj
            for _,kv in ipairs(n.pr or {}) do pcall(function()
                local prop,val=kv[1],kv[2]
                local cur=obj[prop]
                if typeof(cur)=="EnumItem" and type(val)=="number" then
                    local en=tostring(cur):match("^Enum%.([^.]+)%.")
                    local et=en and Enum[en]
                    if et then for _,it in ipairs(et:GetEnumItems()) do if it.Value==val then val=it; break end end end
                elseif typeof(cur)=="BrickColor" and type(val)=="number" then val=BrickColor.new(val) end
                obj[prop]=val
            end) end
        end
    end
    for _,n in ipairs(pack.nodes) do
        local obj=by[n.id]
        if obj then
            for _,kv in ipairs(n.rf or {}) do local ref=by[kv[2]]; if ref then pcall(function() obj[kv[1]]=ref end) end end
            if n.p and n.p~=0 and by[n.p] then obj.Parent=by[n.p] else obj.Parent=target; table.insert(createdRoots,obj) end
        end
    end
    for id,s in pairs(pack.sources or {}) do if by[id] then sourceByInst[by[id]]=s.source end end
    return by
end

-- Build ReplicatedStorage assets first, so GUI/client modules can require them.
local core=get("data/replicated_core.lua")
local coreBy=mount(core,RS)
-- Replace external AnimationManager source with client-only playback.
for inst,src in pairs(sourceByInst) do
    if inst:IsA("ModuleScript") and inst.Name=="AnimationManager" then
        sourceByInst[inst]=game:HttpGet(BASE.."data/client_animation_manager.lua")
    end
end

-- Animation packs are mounted under one local Animations folder.
local animRoot=RS:FindFirstChild("Animations")
if not animRoot then animRoot=Instance.new("Folder"); animRoot.Name="Animations"; animRoot.Parent=RS end
local animFiles={"anim_male.lua","anim_female.lua","anim_bat.lua","anim_other.lua","anim_emotes.lua"}
for _,f in ipairs(animFiles) do
    local ok,pack=pcall(get,"data/"..f)
    if ok and pack then mount(pack,animRoot) end
end

-- Weather resources are local too.
local weather=get("data/weather.lua"); mount(weather,RS)
-- Global post-processing and lighting were physically removed from the place.
local worldFx=get("data/world_fx.lua");mount(worldFx,workspace)
local lightFx=get("data/lighting_fx.lua");mount(lightFx,game:GetService("Lighting"))

-- Player scripts / character scripts / GUI.
local ps=plr:WaitForChild("PlayerScripts")
local pp=get("data/player_scripts.lua"); local ppBy=mount(pp,ps)
local char=plr.Character or plr.CharacterAdded:Wait()
local cp=get("data/character_scripts.lua"); local cpBy=mount(cp,char)
local gui=get("data/starter_gui.lua"); local guiBy=mount(gui,plr:WaitForChild("PlayerGui"))

-- The server character is only an invisible physics/state proxy. The visible R6 shell comes from GitHub.
local rtAssets=Instance.new("Folder");rtAssets.Name="__rt_assets";rtAssets.Parent=RS
local scPack=get("data/starter_character.lua");local scBy=mount(scPack,rtAssets)
local shellTemplate
for _,v in ipairs(rtAssets:GetChildren()) do if v:IsA("Model") and v.Name=="StarterCharacter" then shellTemplate=v break end end
local function attachShell(c)
    if not c or c:FindFirstChild("__rt_shell") or not shellTemplate then return end
    for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then pcall(function()v.LocalTransparencyModifier=1 end) end
        if v:IsA("Decal") then pcall(function()v.Transparency=1 end) end
    end
    for _,v in ipairs(c:GetChildren()) do if v:IsA("Accessory") then pcall(function()v:Destroy()end) end end
    local m=Instance.new("Model");m.Name="__rt_shell";m.Parent=c
    for _,src in ipairs(shellTemplate:GetChildren()) do
        if src:IsA("BasePart") and src.Name~="HumanoidRootPart" then
            local dst=c:FindFirstChild(src.Name)
            if dst and dst:IsA("BasePart") then
                local q=src:Clone();q:BreakJoints();q.Anchored=false;q.CanCollide=false;q.CanTouch=false;q.CanQuery=false;q.Massless=true;q.CFrame=dst.CFrame
                for _,d in ipairs(q:GetDescendants()) do if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then d:Destroy() end end
                q.Parent=m;local w=Instance.new("WeldConstraint");w.Part0=q;w.Part1=dst;w.Parent=q
            end
        end
    end
end
for _,q in ipairs(Players:GetPlayers()) do if q.Character then task.defer(attachShell,q.Character) end;q.CharacterAdded:Connect(function(c)task.wait();attachShell(c)end) end
Players.PlayerAdded:Connect(function(q)q.CharacterAdded:Connect(function(c)task.wait();attachShell(c)end)end)
plr.CharacterAdded:Connect(function(c)task.wait();attachShell(c)end)

-- Execute external LocalScripts after the tree exists.
local function runLocal(packBy)
    for inst,src in pairs(sourceByInst) do
        if inst:IsA("LocalScript") and inst:IsDescendantOf(game) and not inst:GetAttribute("__rt_started") then
            inst:SetAttribute("__rt_started",true)
            task.spawn(function()
                local env=setmetatable({script=inst},{__index=getfenv and getfenv() or _G}); env.require=runtimeRequire
                local fn,er=loadstring(src,"="..inst:GetFullName())
                if not fn then warn("[runtime compile]",inst:GetFullName(),er); return end
                if setfenv then setfenv(fn,env) end
                local ok,e=pcall(fn); if not ok then warn("[runtime]",inst:GetFullName(),e) end
            end)
        end
    end
end
runLocal()

-- Local stats billboards, because the server no longer needs to send GUI templates to clients.
local statsTemplate=RS:FindFirstChild("stats")
local society=RS:FindFirstChild("society")
local offender=RS:FindFirstChild("offender")
local function attachStats(q,c)
    if not statsTemplate then return end
    local h=c:WaitForChild("Head",5); if not h or h:FindFirstChild("stats") then return end
    local x=statsTemplate:Clone(); x.Parent=h; pcall(function()x.Adornee=h end)
    local label=x:FindFirstChild("TextLabel",true); if label then label.Text=q.DisplayName end
    local hum=c:FindFirstChildOfClass("Humanoid")
    if hum then
        local function hp()
            local bar=x:FindFirstChild("health",true); if bar and bar:FindFirstChild("Frame") then bar.Frame.Size=UDim2.new(math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1),0,1,0) end
        end
        hum.HealthChanged:Connect(hp); hp()
    end
    local function meter()
        local bar=x:FindFirstChild("fun",true); if bar and bar:FindFirstChild("Frame") then bar.Frame.Size=UDim2.new(math.clamp(c:GetAttribute("q1199c814b8f7a3e1") or 0,0,1),0,1,0) end
    end
    c:GetAttributeChangedSignal("q1199c814b8f7a3e1"):Connect(meter); meter()
end
for _,q in ipairs(Players:GetPlayers()) do if q.Character then task.spawn(attachStats,q,q.Character) end; q.CharacterAdded:Connect(function(c)attachStats(q,c)end) end
Players.PlayerAdded:Connect(function(q) q.CharacterAdded:Connect(function(c)attachStats(q,c)end) end)

-- Visual bus. The obfuscated real remote was translated to TestAnimation above.
local rem=RS:FindFirstChild("Remotes")
local bus=rem and rem:FindFirstChild("TestAnimation")
local AnimMgr=RS:FindFirstChild("AnimationManager") and runtimeRequire(RS.AnimationManager)
local animHandles={}
local function findPath(root,path)
    local x=root
    for seg in string.gmatch(path,"[^/]+") do seg=aliases[seg] or seg; x=x and x:FindFirstChild(seg) end
    return x
end
local function localSound(id,target,start,dur,speed)
    if type(id)~="string" or not target then return end
    local s=Instance.new("Sound"); s.SoundId=id; s.Parent=target; if start then s.TimePosition=start end; if speed then s.PlaybackSpeed=speed end; s:Play()
    game:GetService("Debris"):AddItem(s,dur or 12)
end
local function flash(c,fill,outline,dur)
    if not c then return end
    local h=Instance.new("Highlight");h.FillColor=fill;h.OutlineColor=outline;h.FillTransparency=.25;h.Parent=c
    game:GetService("TweenService"):Create(h,TweenInfo.new(dur or .5),{FillTransparency=1,OutlineTransparency=1}):Play(); game:GetService("Debris"):AddItem(h,dur or .5)
end
local function namedSound(name,target,start,dur,speed)
    if not target then return end
    local direct={FlashSFX="rbxassetid://462606062",WallBounce="rbxassetid://3923230963",WallBounce2="rbxassetid://5540424854"}
    if direct[name] then return localSound(direct[name],target,start,dur,speed) end
    local roots={RS:FindFirstChild("Sounds"),RS:FindFirstChild("CombatFunctions")}
    for _,root in ipairs(roots) do if root then local t=root:FindFirstChild(name,true); if t and t:IsA("Sound") then local c=t:Clone();c.Parent=target;if start then c.TimePosition=start end;if speed then c.PlaybackSpeed=speed end;c:Play();game:GetService("Debris"):AddItem(c,dur or 12);return end end end
end
local function hitEffect(victim,name,customParent)
    local vfx=RS:FindFirstChild("VFX");local hits=vfx and vfx:FindFirstChild("Hits");if not hits or not victim then return end
    local dest=customParent or victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart");if not dest then return end
    local existing=dest:FindFirstChild(name);if existing and existing:IsA("Attachment") then for _,e in ipairs(existing:GetChildren()) do if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end end;return end
    local t=hits:FindFirstChild(name);if t then local c=t:Clone();c.Parent=dest;for _,e in ipairs(c:GetDescendants()) do if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end end;game:GetService("Debris"):AddItem(c,5) end
end
local function levelup(root,tag)
    local vfx=RS:FindFirstChild("VFX");local f=vfx and vfx:FindFirstChild("LevelUp");if not f or not root then return end
    for _,v in ipairs(f:GetChildren()) do if string.find(v.Name,tag,1,true) then local c=v:Clone();c.Parent=root;if c:IsA("ParticleEmitter") then c:Emit(c:GetAttribute("EmitCount") or 1) end;game:GetService("Debris"):AddItem(c,7) end end;namedSound("LevelUp",root)
end
local function counterFx(attacker,victim)
    local vfx=RS:FindFirstChild("VFX");local t=vfx and vfx:FindFirstChild("Counter");if not t or not attacker then return end
    local c=t:Clone();c.Parent=workspace;local ar=attacker:FindFirstChild("HumanoidRootPart");local vr=victim and victim:FindFirstChild("HumanoidRootPart");if ar and vr and c:IsA("BasePart") then c.CFrame=CFrame.lookAt(ar.Position,Vector3.new(vr.Position.X,ar.Position.Y,vr.Position.Z)) end
    for _,e in ipairs(c:GetDescendants()) do if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end end;game:GetService("Debris"):AddItem(c,5)
end
local function awakenFx(c)
    local vfx=RS:FindFirstChild("VFX");if not vfx or not c then return end;local torso=c:FindFirstChild("Torso");local circles=vfx:FindFirstChild("circles");if circles and torso then local q=circles:Clone();q.Parent=torso;if q:IsA("ParticleEmitter") then q:Emit(35) end;game:GetService("Debris"):AddItem(q,5) end
    local ks=vfx:FindFirstChild("Killstreak");if ks then for _,part in ipairs(c:GetChildren()) do if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and part.Name~="Torso" then for _,v in ipairs(ks:GetChildren()) do if v:IsA("ParticleEmitter") then local q=v:Clone();q.Parent=part;q.Enabled=true;game:GetService("Debris"):AddItem(q,4) elseif v:IsA("Highlight") then local q=v:Clone();q.Parent=c;game:GetService("Debris"):AddItem(q,3) end end end end end
end
local function juiceFx(target,n1,n2)
    if not target then return end;local morph=target:FindFirstChild("boba") or target:FindFirstChild("pp");local juice=morph and morph:FindFirstChild("juice",true);if not juice then return end;local blood=juice:FindFirstChild("Blood",true);if blood and blood:IsA("ParticleEmitter") then blood:Emit(n1 or 1) end;local pe=juice:FindFirstChildWhichIsA("ParticleEmitter");if pe then pe:Emit(n2 or 1) end
end
if bus then bus.OnClientEvent:Connect(function(op,...)
    local a={...}
    if op=="A" and AnimMgr then local id,path,c=a[1],a[2],a[3]; local seq=findPath(animRoot,path); if seq then animHandles[id]=AnimMgr.PlayAnimation(seq,c) end
    elseif op=="AS" and AnimMgr then local id=a[1]; if animHandles[id] then AnimMgr.StopAnimation(animHandles[id]); animHandles[id]=nil end
    elseif op=="AV" and AnimMgr then local id,s=a[1],a[2]; if animHandles[id] then AnimMgr.ChangeAnimationSpeed(animHandles[id],s) end
    elseif op=="S" then localSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="SN" then namedSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="HS" then namedSound(a[1],a[2] and (a[2]:FindFirstChild("HumanoidRootPart") or a[2]))
    elseif op=="F" then flash(a[1],a[2],a[3],a[4])
    elseif op=="H" then hitEffect(a[1],a[2],a[3])
    elseif op=="L" then levelup(a[1],a[2])
    elseif op=="C" then counterFx(a[1],a[2])
    elseif op=="W" then awakenFx(a[1])
    elseif op=="P" then juiceFx(a[1],a[2],a[3])
    elseif op=="ASTOPCHAR" and AnimMgr then local c=a[1];if c and c:FindFirstChildOfClass("Humanoid") then AnimMgr.StopAnimationOnHumanoid(c:FindFirstChildOfClass("Humanoid")) end
    elseif op=="M+" then local m=RS:FindFirstChild("NewChanger"); if m then local mm=runtimeRequire(m); pcall(function()mm:loadMorph(a[1],a[2])end) end
    elseif op=="M-" then local m=RS:FindFirstChild("NewChanger"); if m then local mm=runtimeRequire(m); pcall(function()mm:clearMorph(a[1],a[2])end) end
    end
end) end

-- Server-private presentation is represented by state only; the actual UI exists here.\nlocal ADMIN_ATTR="x85336ab0ff8a"\nlocal OWNER_ATTR="x2ca41220f81e"\nlocal DUMMY_ATTR="x9e463bebdb55"\nlocal DUMMY_NAME_ATTR="x6ccd4e242b40"\nlocal function mountOnce(file,target,marker)\n    if target:FindFirstChild(marker) then return end\n    local pack=get("data/"..file);local by=mount(pack,target);for _,r in ipairs(pack.roots or {}) do local x=by[r];if x then x.Name=marker end end;runLocal()\nend\nlocal function adminCheck() if plr:GetAttribute(ADMIN_ATTR) then mountOnce("admin_gui.lua",plr.PlayerGui,"__rt_admin") end end\nplr:GetAttributeChangedSignal(ADMIN_ATTR):Connect(adminCheck);adminCheck()\nlocal ownerStore=Instance.new("Folder");ownerStore.Name="__rt_owner_asset";ownerStore.Parent=rtAssets\nlocal ownerPack=get("data/owner_tag.lua");local ownerBy=mount(ownerPack,ownerStore);local ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui")\nlocal infoStore=Instance.new("Folder");infoStore.Name="__rt_info_asset";infoStore.Parent=rtAssets\nlocal infoPack=get("data/info_gui.lua");local infoBy=mount(infoPack,infoStore);local infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui")\nlocal function attachLabels(q,c)\n    local h=c:WaitForChild("Head",5);if not h then return end\n    if infoTemplate and not h:FindFirstChild("Info") then\n        local x=infoTemplate:Clone();x.Name="Info";x.Parent=h;pcall(function()x.Adornee=h end)\n        local nt=x:FindFirstChild("NameText",true);if nt then nt.Text=q.DisplayName;local bg=nt:FindFirstChild("Background");if bg then bg.Text=q.DisplayName end end\n        local function gender() local g=q:GetAttribute("qe8be68a176690a76") or "";local gt=x:FindFirstChild("GenderText",true);if gt then gt.Text=g;local bg=gt:FindFirstChild("Background");if bg then bg.Text=g end end end\n        q:GetAttributeChangedSignal("qe8be68a176690a76"):Connect(gender);gender()\n    end\n    if ownerTemplate and q:GetAttribute(OWNER_ATTR) and not h:FindFirstChild("__rt_owner") then local x=ownerTemplate:Clone();x.Name="__rt_owner";x.Parent=h;pcall(function()x.Adornee=h end) end\nend\nfor _,q in ipairs(Players:GetPlayers()) do if q.Character then task.defer(attachLabels,q,q.Character) end;q.CharacterAdded:Connect(function(c)attachLabels(q,c)end) end\nPlayers.PlayerAdded:Connect(function(q)q.CharacterAdded:Connect(function(c)attachLabels(q,c)end)end)\n-- Runtime-only background music. No Sound instance remains stored in the place.\ntask.spawn(function()\n    local ids={1845341094,9046863253,9046864509,9043887091,1847506405,1837871067,1843468325,1845490105}\n    local s=Instance.new("Sound");s.Name="__rt_music";s.Volume=.2;s.Parent=game:GetService("SoundService")\n    while s.Parent do s.SoundId="rbxassetid://"..ids[math.random(1,#ids)];s:Play();s.Ended:Wait();task.wait(3) end\nend)\n-- Dummies are server-side invisible proxy rigs too.\nlocal function dummy(c)\n    if not c:IsA("Model") or not c:GetAttribute(DUMMY_ATTR) then return end\n    attachShell(c)\n    local fake={DisplayName=c:GetAttribute(DUMMY_NAME_ATTR) or "DUMMY",GetAttribute=function(_,k)return c:GetAttribute(k)end,GetAttributeChangedSignal=function(_,k)return c:GetAttributeChangedSignal(k)end}\n    local h=c:FindFirstChild("Head");if h and statsTemplate and not h:FindFirstChild("stats") then local x=statsTemplate:Clone();x.Parent=h;pcall(function()x.Adornee=h end);local label=x:FindFirstChild("TextLabel",true);if label then label.Text=fake.DisplayName end end\nend\nfor _,v in ipairs(workspace:GetChildren()) do dummy(v) end\nworkspace.ChildAdded:Connect(function(v)task.defer(dummy,v)end)\nprint("[FunCombat Runtime] mounted",#createdRoots,"external roots")\nreturn true\nend\n