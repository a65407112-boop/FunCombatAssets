    if not foundPrnt then error("RBXM has no PRNT chunk") end
    return table.concat(out)
end

local paths={}
local function download(name)
    if paths[name] then return paths[name] end
    status("downloading "..name,false)
    local ok,data=pcall(function()return game:HttpGet(BASE..name.."?v="..tostring(math.floor(os.clock()*1000000)))end)
    if not ok or type(data)~="string" or #data<32 then error("download failed "..name..": "..tostring(data)) end
    if data:find("404: Not Found",1,true) or data:sub(1,1)=="{" then error("GitHub returned text for "..name) end
    if MULTI[name] then
        status("packing all roots for "..name,false)
        data=wrapMultiRoot(data)
    end
    local path=CACHE.."/"..name
    writefile(path,data);task.wait(.08);paths[name]=path
    return path
end
local function getObjects(path)
    local attempts={path,"./"..path}
    if type(getcustomasset)=="function" then
        local ok,a=pcall(getcustomasset,path);if ok and a then attempts[#attempts+1]=a end
    end
    local last
    for _,candidate in ipairs(attempts) do
        local ok,res=pcall(function()return game:GetObjects(candidate)end)
        if ok then
            if typeof(res)=="Instance" then return {res} end
            if type(res)=="table" and #res>0 then return res end
        else last=res end
    end
    error("executor could not deserialize "..path.." | "..tostring(last))
end
local packCache={}
local function import(name)
    if packCache[name] then
        local out={};for _,r in ipairs(packCache[name]) do out[#out+1]=r:Clone() end;return out
    end
    local roots=getObjects(download(name))
    if #roots==1 and roots[1].Name=="__FunCombatPack" then
        local wrapper=roots[1];roots={}
        for _,c in ipairs(wrapper:GetChildren()) do c.Parent=nil;roots[#roots+1]=c end
        pcall(function()wrapper:Destroy()end)
    end
    packCache[name]=roots
    return roots
end
local function freezeLocals(root)
    if root:IsA("LocalScript") then pcall(function()root.Disabled=true end) end
    for _,d in ipairs(root:GetDescendants()) do if d:IsA("LocalScript") then pcall(function()d.Disabled=true end) end end
end
local function mount(name,target)
    local roots=import(name)
    for _,r in ipairs(roots) do freezeLocals(r);r:SetAttribute("__FunCombatImported",true);r.Parent=target;track(r) end
    return roots
end

-- Critical GUI keeps its original RBXM visuals, but its old LocalScripts are not
-- manually executed. They were written for the original place hierarchy and can
-- half-start, yield on an old path, then leave a perfectly visible dead button.
-- The server-authoritative bridge in parts 5/6 owns these controls instead.
local criticalGui={Gender=true,Emotes=true,weapon=true,weaponGui=true,getUp=true,HitboxToggle=true,MapVoteGui=true,mobileButtons=true}
local function isCriticalGuiScript(ls)
    local sg=ls and ls:FindFirstAncestorWhichIsA("ScreenGui")
    return sg and criticalGui[sg.Name] or false
end

-- Try to execute preserved non-critical LocalScript source when Xeno exposes it.
local function runLocal(ls)
    if not ls or not ls:IsA("LocalScript") or ls:GetAttribute("__FCRan") then return false end
    if ls:FindFirstAncestorWhichIsA("Tool") then return false end
    if isCriticalGuiScript(ls) then
        ls:SetAttribute("__FCBridgeOwned",true)
        return false
    end
    if ls.Name=="main" and ls.Parent and ls.Parent.Name=="StarterCharacterScripts" then return false end
    runtime.localFound=runtime.localFound+1
    local okSrc,src=pcall(function()return ls.Source end)
    if not okSrc or type(src)~="string" or src=="" or type(loadstring)~="function" or type(setfenv)~="function" then
        runtime.localUnreadable=runtime.localUnreadable+1;return false
    end
    local fn,err=loadstring(src,"@"..ls:GetFullName())
    if not fn then runtime.localFailed=runtime.localFailed+1;warn("[FC] compile "..ls:GetFullName()..": "..tostring(err));return false end
    local base=(getfenv and getfenv(fn)) or ENV
    local env=setmetatable({script=ls},{__index=base})
    local okEnv=pcall(setfenv,fn,env)
    if not okEnv then runtime.localFailed=runtime.localFailed+1;return false end
    ls:SetAttribute("__FCRan",true);runtime.localStarted=runtime.localStarted+1
    task.spawn(function()
        local okRun,runErr=xpcall(fn,function(e)return (debug and debug.traceback and debug.traceback(tostring(e),2)) or tostring(e) end)
        if not okRun then
            ls:SetAttribute("__FCRan",nil)
            ls:SetAttribute("__FCRunFailed",true)
            runtime.localFailed=runtime.localFailed+1
            warn("[FC local] "..ls:GetFullName()..": "..tostring(runErr))
        end
    end)
    return true
end
local function runTree(root)
    if root:IsA("LocalScript") then runLocal(root) end
    for _,d in ipairs(root:GetDescendants()) do if d:IsA("LocalScript") then runLocal(d) end end
end

-- Core presentation packs.
status("mounting presentation assets",false)
for _,name in ipairs({"AnimationManager","Rig","Weather","VFX","Sounds","NewMorphs","NewChanger","stats","society","offender","Animations"}) do
    local x=RS:FindFirstChild(name);if x and x:GetAttribute("__FunCombatImported") then pcall(function()x:Destroy()end) end
end
mount("VFX.rbxm",RS);mount("Sounds.rbxm",RS);mount("Weather.rbxm",RS);mount("Rig.rbxm",RS)
mount("NewMorphs.rbxm",RS);mount("NewChanger_ClientPresentation.rbxm",RS);mount("Billboards.rbxm",RS);mount("AnimationManager.rbxm",RS)
mount("Lighting.rbxm",Lighting)

local animations=RS:FindFirstChild("Animations")
if not animations then animations=Instance.new("Folder");animations.Name="Animations";animations:SetAttribute("__FunCombatImported",true);animations.Parent=RS;track(animations) end
local animFiles={male="Animations_male.rbxm",female="Animations_female.rbxm",bat="Animations_bat.rbxm",other="Animations_other.rbxm",Emotes="Animations_Emotes.rbxm"}
local animLoaded={};local animLoading={}
local function findPath(root,path)
    local x=root;for seg in string.gmatch(tostring(path or ""),"[^/]+") do x=x and x:FindFirstChild(seg) end;return x
end
local function ensureAnimation(path)
    local found=findPath(animations,path);if found then return found end
