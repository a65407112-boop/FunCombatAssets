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
    s=tostring(s)
    table.insert(ENV.__NULL_ERRORS,s)
    warn("[Null Protocol] "..s)
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,205,120)
            diagLabel.Text="Null Protocol: "..s
        end
    end)
end

local function fail(s)
    s=tostring(s)
    table.insert(ENV.__NULL_ERRORS,s)
    warn("[Null Protocol] "..s)
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,120,120)
            diagLabel.Text="Null Protocol ERROR:\n"..s
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

    -- Older exporter build accidentally wrote literal \\n sequences in the tail.
    local marker="-- Server-private presentation is represented by state only; the actual UI exists here."
    local p=src:find(marker,1,true)
    if p then
        local head,tail=src:sub(1,p-1),src:sub(p)
        if tail:find("\\n",1,true) then
            tail=tail:gsub("\\n","\n")
            src=head..tail
        end
    end

    -- Repair malformed serialized Lua before compiling every downloaded pack.
    local oldGet=[[local function get(path)
    local s=game:HttpGet(BASE..path)
    local f,e=loadstring(s,"@"..path); if not f then error(e) end
    return f()
end]]
    local newGet=[[local __rtPackCache={}
local function get(path)
    if __rtPackCache[path] then return __rtPackCache[path] end
    print("[Null Protocol] downloading "..path)
    local s=game:HttpGet(BASE..path)
    local fixed,keyFixes=s:gsub("%[%[%[([%w_%-]+)%]%]%]%s*=", '["%1"]=')
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

    -- Yield while mounting giant packs. Same final instances, less one-frame murder.
    local replacements=0
    src,replacements=src:gsub("for _,n in ipairs%(pack%.nodes%) do", "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%200==0 then task.wait() end", 2)
    if replacements>0 then stage("enabled chunked mounting") end

    -- Do not preload ~50k animation/keyframe objects before the UI exists.
    local a=src:find("-- Animation packs are mounted under one local Animations folder.",1,true)
    local b=a and src:find("-- Weather resources are local too.",a,true)
    if a and b then src=src:sub(1,a-1)..src:sub(b) end

    -- Optional overhead UI must never abort the whole runtime.
    local oldOwner='local ownerPack=get("data/owner_tag.lua");local ownerBy=mount(ownerPack,ownerStore);local ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui")'
    local newOwner='local ownerTemplate=nil;local okOwner,ownerPack=pcall(get,"data/owner_tag.lua");if okOwner and ownerPack then mount(ownerPack,ownerStore);ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional owner_tag skipped: "..tostring(ownerPack)) end'
    src=select(1,replaceOnce(src,oldOwner,newOwner))
    local oldInfo='local infoPack=get("data/info_gui.lua");local infoBy=mount(infoPack,infoStore);local infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui")'
    local newInfo='local infoTemplate=nil;local okInfo,infoPack=pcall(get,"data/info_gui.lua");if okInfo and infoPack then mount(infoPack,infoStore);infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional info_gui skipped: "..tostring(infoPack)) end'
    src=select(1,replaceOnce(src,oldInfo,newInfo))

    -- Replace the two original Gender scripts with a server-acknowledged controller.
    -- The original only waited 0.1 s, so normal network latency could leave the menu stuck forever.
    local guiNeedle='local gui=get("data/starter_gui.lua"); local guiBy=mount(gui,plr:WaitForChild("PlayerGui"))'
    local genderPatch=[[

-- Runtime repair for the original Gender selector.
do
    local GENDER_ATTR="qe8be68a176690a76"
    local genderGui=plr.PlayerGui:FindFirstChild("Gender")
    for inst,_ in pairs(sourceByInst) do
        if inst:IsA("LocalScript") and inst:FindFirstAncestor("Gender") then
            if inst.Name=="Buttons" then
                sourceByInst[inst]=[=[
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local ATTR="qe8be68a176690a76"
local frame=script.Parent
local screen=script:FindFirstAncestor("Gender")
if not screen then return end

local attrSystem=RS:WaitForChild("AttributeSystem",10)
local setInfoEvent=attrSystem and attrSystem:WaitForChild("SetInfo",10)
if not setInfoEvent then
    warn("[Null Protocol] Gender SetInfo remote missing")
    return
end

local busy=false
local function sync()
    if player:GetAttribute(ATTR) then
        screen.Enabled=false
    end
end
player:GetAttributeChangedSignal(ATTR):Connect(sync)
sync()

for _,button in ipairs(frame:GetChildren()) do
    if button:IsA("TextButton") then
        button.MouseEnter:Connect(function()
            local s=script:FindFirstChild("Hover")
            if s then local c=s:Clone();c.Parent=workspace.CurrentCamera;c:Play();game:GetService("Debris"):AddItem(c,5) end
        end)
        button.Activated:Connect(function()
            if busy then return end
            busy=true
            local click=script:FindFirstChild("Click")
            if click then local c=click:Clone();c.Parent=workspace.CurrentCamera;c:Play();game:GetService("Debris"):AddItem(c,5) end

            if not tonumber(button.Name) then
                setInfoEvent:FireServer(ATTR,button.Text)
                -- Hide immediately for responsive UI. Restore only if server never acknowledges.
                screen.Enabled=false
                local deadline=os.clock()+5
                repeat task.wait(.05) until player:GetAttribute(ATTR) or os.clock()>=deadline
                if not player:GetAttribute(ATTR) then
                    screen.Enabled=true
                    warn("[Null Protocol] Gender selection was not acknowledged by server")
                end
            end
            busy=false
        end)
    end
end
]=]
            elseif inst.Parent==genderGui then
                sourceByInst[inst]=[=[
local player=game:GetService("Players").LocalPlayer
local ATTR="qe8be68a176690a76"
local gui=script.Parent
local function sync()
    gui.Enabled=not not (not player:GetAttribute(ATTR))
end
player:GetAttributeChangedSignal(ATTR):Connect(sync)
sync()
]=]
            end
        end
    end
end
]]
    src,ok=insertAfter(src,guiNeedle,genderPatch)
    if not ok then error("gender patch point not found") end

    -- Surface LocalScript compile/runtime failures instead of silently eating them.
    local oldCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er); return end'
    local newCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er);pcall(function()local e=(getgenv and getgenv()) or _G;if e.__NULL_REPORT then e.__NULL_REPORT("LocalScript compile: "..inst:GetFullName().." | "..tostring(er)) end end);return end'
    src=select(1,replaceOnce(src,oldCompile,newCompile))
    local oldRuntime='local ok,e=pcall(fn); if not ok then warn("[runtime]",inst:GetFullName(),e) end'
    local newRuntime='local ok,e=pcall(fn);if not ok then warn("[runtime]",inst:GetFullName(),e);pcall(function()local g=(getgenv and getgenv()) or _G;if g.__NULL_REPORT then g.__NULL_REPORT("LocalScript runtime: "..inst:GetFullName().." | "..tostring(e)) end end) end'
    src=select(1,replaceOnce(src,oldRuntime,newRuntime))

    -- Heavy resources stay lazy, but can now mount in chunks without freezing the client.
    local hook=[[runLocal()]]
    local heavy=[[

do
    local env=(getgenv and getgenv()) or _G
    local loadedRig=false
    local loadedAnim={}

    env.__NULL_LOAD_RIG=function()
        if loadedRig then return true end
        loadedRig=true
        print("[Null Protocol] loading rig_assets.lua")
        local okRig,pack=pcall(get,"data/rig_assets.lua")
        if not okRig then loadedRig=false;warn("[Null Protocol] rig load failed: "..tostring(pack));return false end
        mount(pack,RS)
        print("[Null Protocol] rig assets mounted")
        return true
    end

    env.__NULL_LOAD_ANIM=function(file)
        file=file or "anim_male.lua"
        local allowed={anim_male=true,anim_female=true,anim_bat=true,anim_other=true,anim_emotes=true}
        local stem=file:gsub("%.lua$","")
        if not allowed[stem] then error("invalid animation pack") end
        if loadedAnim[stem] then return true end
        loadedAnim[stem]=true
        local root=RS:FindFirstChild("Animations")
        if not root then root=Instance.new("Folder");root.Name="Animations";root.Parent=RS end
        print("[Null Protocol] loading "..file)
        local okAnim,pack=pcall(get,"data/"..file)
        if not okAnim then loadedAnim[stem]=nil;warn("[Null Protocol] animation pack failed: "..tostring(pack));return false end
        mount(pack,root)
        print("[Null Protocol] mounted "..file)
        return true
    end
end
]]
    src,ok=insertAfter(src,hook,heavy)
    if not ok then error("runLocal hook not found") end

    return src
end

local function auditMenus(pg)
    local expected={
        "HitboxToggle","Shiftlock","getUp","meter","mobileButtons","Emotes",
        "Gender","MapVoteGui","weapon","weaponGui"
    }
    local missing={}
    for _,name in ipairs(expected) do
        if not pg:FindFirstChild(name) then table.insert(missing,name) end
    end

    local buttons=0
    for _,v in ipairs(pg:GetDescendants()) do
        if v:IsA("GuiButton") then buttons+=1 end
    end

    -- Fallback for the weapon-menu opener. If its original LocalScript works,
    -- this does nothing; if it fails, this restores the toggle after 0.12 s.
    local weapon=pg:FindFirstChild("weapon")
    local weaponGui=pg:FindFirstChild("weaponGui")
    if weapon and weaponGui then
        local opener=weaponGui:FindFirstChildWhichIsA("GuiButton",true)
        if opener then
            opener.Activated:Connect(function()
                local before=weapon.Enabled
                task.delay(.12,function()
                    if weapon.Parent and weapon.Enabled==before then
                        weapon.Enabled=not before
                    end
                end)
            end)
        end
    end

    -- Emote animations are loaded only when the user actually touches the emote UI.
    local emotes=pg:FindFirstChild("Emotes")
    if emotes then
        local armed=true
        for _,v in ipairs(emotes:GetDescendants()) do
            if v:IsA("GuiButton") then
                v.Activated:Connect(function()
                    if not armed then return end
                    armed=false
                    task.spawn(function()
                        if ENV.__NULL_LOAD_ANIM then ENV.__NULL_LOAD_ANIM("anim_emotes.lua") end
                    end)
                end)
            end
        end
    end

    if #missing>0 then
        report("UI audit: missing "..table.concat(missing,", "))
    else
        stage("UI audit OK | "..tostring(buttons).." buttons | menus mounted")
    end
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
    auditMenus(pg)

    -- Rig/model assets are useful to weapon/morph menus, but mount after UI is already responsive.
    task.delay(1.5,function()
        if ENV.__NULL_LOAD_RIG then
            local okRig,err=pcall(ENV.__NULL_LOAD_RIG)
            if not okRig then report("background rig load: "..tostring(err)) end
        end
    end)

    task.delay(4,function()
        pcall(function()
            if diagGui and #ENV.__NULL_ERRORS==0 then diagGui:Destroy() end
        end)
    end)

    return value
end,function(e)
    local tr=tostring(e)
    pcall(function()if debug and debug.traceback then tr=debug.traceback(tr,2) end end)
    fail(tr)
    return tr
end)

if not ok then return nil,result end
return result
