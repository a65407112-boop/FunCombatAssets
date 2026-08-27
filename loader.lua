-- Null Protocol / Fun Combat runtime loader
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

ENV.__NULL_ERRORS = ENV.__NULL_ERRORS or {}

local diagGui, diagLabel
pcall(function()
    local pg = plr:WaitForChild("PlayerGui",10)
    if not pg then return end
    local old = pg:FindFirstChild("__NullProtocolLoader")
    if old then old:Destroy() end

    diagGui = Instance.new("ScreenGui")
    diagGui.Name = "__NullProtocolLoader"
    diagGui.ResetOnSpawn = false
    diagGui.DisplayOrder = 1000000
    diagGui.IgnoreGuiInset = true
    diagGui.Parent = pg

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(.5,0)
    frame.Position = UDim2.new(.5,0,0,18)
    frame.Size = UDim2.new(0,760,0,88)
    frame.BackgroundColor3 = Color3.fromRGB(15,15,18)
    frame.BackgroundTransparency = .06
    frame.BorderSizePixel = 0
    frame.Parent = diagGui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=frame

    diagLabel=Instance.new("TextLabel")
    diagLabel.BackgroundTransparency=1
    diagLabel.Position=UDim2.new(0,14,0,7)
    diagLabel.Size=UDim2.new(1,-28,1,-14)
    diagLabel.Font=Enum.Font.Code
    diagLabel.TextSize=16
    diagLabel.TextWrapped=true
    diagLabel.TextXAlignment=Enum.TextXAlignment.Left
    diagLabel.TextYAlignment=Enum.TextYAlignment.Center
    diagLabel.TextColor3=Color3.new(1,1,1)
    diagLabel.Text="Null Protocol: loader started"
    diagLabel.Parent=frame
end)

local function stage(s)
    print("[Null Protocol] "..tostring(s))
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.new(1,1,1)
            diagLabel.Text="Null Protocol: "..tostring(s)
        end
    end)
end

local function report(s)
    local msg=tostring(s)
    warn("[Null Protocol] "..msg)
    table.insert(ENV.__NULL_ERRORS,msg)
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,205,120)
            diagLabel.Text="Null Protocol: "..msg
        end
    end)
end

local function fail(s)
    local msg=tostring(s)
    warn("[Null Protocol] "..msg)
    table.insert(ENV.__NULL_ERRORS,msg)
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,120,120)
            diagLabel.Text="Null Protocol ERROR:\n"..msg
        end
    end)
end

ENV.__NULL_REPORT=report

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"

local function replaceOnce(src,needle,repl)
    local p=src:find(needle,1,true)
    if not p then return src,false end
    return src:sub(1,p-1)..repl..src:sub(p+#needle),true
end

local function insertAfter(src,needle,text)
    local p=src:find(needle,1,true)
    if not p then return src,false end
    local a=p+#needle
    return src:sub(1,a-1)..text..src:sub(a),true
end

local function patchCore(src)
    stage("patching core")

    local marker="-- Server-private presentation is represented by state only; the actual UI exists here."
    local p=src:find(marker,1,true)
    if p then
        local head,tail=src:sub(1,p-1),src:sub(p)
        if tail:find("\\n",1,true) then
            tail=tail:gsub("\\n","\n")
            src=head..tail
        end
    end

    local oldGet=[[local function get(path)
    local s=game:HttpGet(BASE..path)
    local f,e=loadstring(s,"@"..path); if not f then error(e) end
    return f()
end]]

    local newGet=[[local __rtPackCache={}
local function get(path)
    if __rtPackCache[path]~=nil then return __rtPackCache[path] end
    print("[Null Protocol] downloading "..path)
    local s=game:HttpGet(BASE..path)
    local fixed,keyFixes=s:gsub("%[%[%[([%w_%-]+)%]%]%]%s*=", function(key)
        return '["'..key..'"]='
    end)
    local valueFixes=0
    fixed,valueFixes=fixed:gsub("({%[%[[%w_]+%]%],)%[%[(.-)%]%]%](},)",function(prefix,body,suffix)
        return prefix..string.format("%q",body.."]")..suffix
    end)
    if keyFixes+valueFixes>0 then
        print("[Null Protocol] repaired "..tostring(keyFixes+valueFixes).." serialized fields in "..path)
    end
    local f,e=loadstring(fixed,"@"..path)
    if not f then error("DATA COMPILE FAILED "..path..": "..tostring(e)) end
    local value=f()
    __rtPackCache[path]=value
    return value
end]]

    local ok
    src,ok=replaceOnce(src,oldGet,newGet)
    if not ok then error("data-loader patch point not found") end

    -- Yield while mounting giant packs. The replacement string must escape %
    -- because string.gsub interprets %2 etc. as capture references.
    local replacements=0
    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%%200==0 then task.wait() end",
        2
    )
    if replacements>0 then stage("enabled chunked mounting") end

    local a=src:find("-- Animation packs are mounted under one local Animations folder.",1,true)
    local b=a and src:find("-- Weather resources are local too.",a,true)
    if a and b then src=src:sub(1,a-1)..src:sub(b) end

    local oldOwner='local ownerPack=get("data/owner_tag.lua");local ownerBy=mount(ownerPack,ownerStore);local ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui")'
    local newOwner='local ownerTemplate=nil;local okOwner,ownerPack=pcall(get,"data/owner_tag.lua");if okOwner and ownerPack then mount(ownerPack,ownerStore);ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional owner_tag skipped: "..tostring(ownerPack)) end'
    src=select(1,replaceOnce(src,oldOwner,newOwner))

    local oldInfo='local infoPack=get("data/info_gui.lua");local infoBy=mount(infoPack,infoStore);local infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui")'
    local newInfo='local infoTemplate=nil;local okInfo,infoPack=pcall(get,"data/info_gui.lua");if okInfo and infoPack then mount(infoPack,infoStore);infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional info_gui skipped: "..tostring(infoPack)) end'
    src=select(1,replaceOnce(src,oldInfo,newInfo))

    local oldCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er); return end'
    local newCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er);pcall(function()local e=(getgenv and getgenv()) or _G;if e.__NULL_REPORT then e.__NULL_REPORT("LocalScript compile: "..inst:GetFullName().." | "..tostring(er)) end end);return end'
    src=select(1,replaceOnce(src,oldCompile,newCompile))

    local oldRuntime='local ok,e=pcall(fn); if not ok then warn("[runtime]",inst:GetFullName(),e) end'
    local newRuntime='local ok,e=pcall(fn);if not ok then warn("[runtime]",inst:GetFullName(),e);pcall(function()local g=(getgenv and getgenv()) or _G;if g.__NULL_REPORT then g.__NULL_REPORT("LocalScript runtime: "..inst:GetFullName().." | "..tostring(e)) end end) end'
    src=select(1,replaceOnce(src,oldRuntime,newRuntime))

    -- Make Gender selector robust: hide immediately after a click, then wait for
    -- server confirmation for a few seconds. Reopen only if the choice failed.
    local oldGender=[[\t\twait(.1) -- allow properties to be set, task.defer is too fast.
\t\t
\t\tif player:GetAttribute("qe8be68a176690a76") then
\t\t\tscript.Parent.Parent.Enabled = false 
\t\t\t--player.PlayerGui:WaitForChild("main").Enabled = true
\t\t\t
\t\tend]]
    local newGender=[[        script.Parent.Parent.Enabled = false
        local deadline=os.clock()+5
        while os.clock()<deadline and not player:GetAttribute("qe8be68a176690a76") do
            task.wait(.05)
        end
        if not player:GetAttribute("qe8be68a176690a76") then
            warn("Gender selection was not confirmed by server")
            script.Parent.Parent.Enabled = true
        end]]
    src=select(1,replaceOnce(src,oldGender,newGender))

    -- The original tiny helper enables Gender every runtime start. Disable that
    -- behavior once the server attribute already exists.
    local oldGenderEnable='[171]={class=[[LocalScript]],source=[[script.Parent.Enabled = true]]}'
    local newGenderEnable='[171]={class=[[LocalScript]],source=[[local p=game:GetService("Players").LocalPlayer;script.Parent.Enabled = not not (not p:GetAttribute("qe8be68a176690a76"))]]}'
    src=select(1,replaceOnce(src,oldGenderEnable,newGenderEnable))

    -- Delay heavy rig restoration until after UI scripts are running.
    local runHook="runLocal()"
    local afterRun=[[

-- Heavy visual models are restored after the menus are alive.
task.spawn(function()
    task.wait(2)
    print("[Null Protocol] loading rig_assets.lua")
    local okRig,rigPack=pcall(get,"data/rig_assets.lua")
    if okRig and rigPack then
        mount(rigPack,RS)
        print("[Null Protocol] rig assets mounted")
    else
        warn("[Null Protocol] rig assets skipped: "..tostring(rigPack))
    end
end)

-- Large animation packs are lazy. Emote animations are loaded when Emotes is used.
do
    local env=(getgenv and getgenv()) or _G
    env.__NULL_LOAD_ANIM=function(file)
        file=file or "anim_male.lua"
        local allowed={anim_male=true,anim_female=true,anim_bat=true,anim_other=true,anim_emotes=true}
        local stem=file:gsub("%.lua$","")
        if not allowed[stem] then return false,"invalid animation pack" end
        local root=RS:FindFirstChild("Animations")
        if not root then root=Instance.new("Folder");root.Name="Animations";root.Parent=RS end
        local okPack,pack=pcall(get,"data/"..file)
        if not okPack then return false,pack end
        mount(pack,root)
        print("[Null Protocol] mounted "..file)
        return true
    end
end
]]
    src,ok=insertAfter(src,runHook,afterRun)
    if not ok then error("runLocal hook not found") end

    return src
end

local ok,result=xpcall(function()
    stage("downloading core.lua")
    local src=game:HttpGet(BASE.."core.lua?cb="..tostring(math.floor(os.clock()*1000000)))
    stage("core downloaded: "..tostring(#src).." bytes")
    src=patchCore(src)

    stage("compiling core")
    local fn,er=loadstring(src,"NullProtocolCore")
    if not fn then error("CORE COMPILE FAILED: "..tostring(er)) end

    local factory=fn()
    if type(factory)~="function" then error("core.lua did not return a function") end

    stage("starting runtime")
    local value=factory(BASE)

    local pg=plr:WaitForChild("PlayerGui")

    -- UI audit and compatibility fixes.
    local expected={
        "HitboxToggle","Shiftlock","getUp","meter","mobileButtons","title",
        "Subtitles","Emotes","awakenScreen","Gender","yeah","MapVoteGui",
        "weapon","weaponGui"
    }
    local present,missing={},{}
    for _,name in ipairs(expected) do
        if pg:FindFirstChild(name) then table.insert(present,name) else table.insert(missing,name) end
    end
    print("[Null Protocol] GUI present: "..table.concat(present,", "))
    if #missing>0 then report("GUI missing: "..table.concat(missing,", ")) end

    -- weaponGui's original controller is simple; install a fallback only when both
    -- expected GUIs exist. This is harmless if the original callback also runs.
    local weaponGui=pg:FindFirstChild("weaponGui")
    local weapon=pg:FindFirstChild("weapon")
    if weaponGui and weapon then
        for _,v in ipairs(weaponGui:GetDescendants()) do
            if v:IsA("GuiButton") and not v:GetAttribute("__NullFallback") then
                v:SetAttribute("__NullFallback",true)
                v.Activated:Connect(function()
                    weapon.Enabled=not weapon.Enabled
                end)
            end
        end
    end

    -- Load emote keyframes only after the user actually interacts with Emotes.
    local emotes=pg:FindFirstChild("Emotes")
    if emotes then
        local armed=false
        for _,v in ipairs(emotes:GetDescendants()) do
            if v:IsA("GuiButton") then
                v.Activated:Connect(function()
                    if armed then return end
                    armed=true
                    task.spawn(function()
                        local okAnim,animErr=ENV.__NULL_LOAD_ANIM("anim_emotes.lua")
                        if not okAnim then report("anim_emotes: "..tostring(animErr)) end
                    end)
                end)
            end
        end
    end

    stage("RUNTIME READY | UI="..tostring(#present).."/"..tostring(#expected))
    return value
end,function(e)
    local tr=tostring(e)
    pcall(function()
        if debug and debug.traceback then tr=debug.traceback(tr,2) end
    end)
    fail(tr)
    return tr
end)

if not ok then return nil,result end
return result
