-- Null Protocol / Fun Combat SAFE runtime loader
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

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
    frame.Size = UDim2.new(0,700,0,86)
    frame.BackgroundColor3 = Color3.fromRGB(15,15,18)
    frame.BackgroundTransparency = .06
    frame.BorderSizePixel = 0
    frame.Parent = diagGui
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=frame
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
    diagLabel.Text="Null Protocol: SAFE loader started"
    diagLabel.Parent=frame
end)

local function stage(s)
    print("[Null Protocol] "..tostring(s))
    pcall(function() if diagLabel then diagLabel.Text="Null Protocol: "..tostring(s) end end)
end
local function report(s)
    warn("[Null Protocol] "..tostring(s))
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,205,120)
            diagLabel.Text="Null Protocol: "..tostring(s)
        end
    end)
end
local function fail(s)
    warn("[Null Protocol] "..tostring(s))
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3=Color3.fromRGB(255,120,120)
            diagLabel.Text="Null Protocol ERROR:\n"..tostring(s)
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

    -- Repair malformed literal \\n tail from the old exporter build.
    local marker="-- Server-private presentation is represented by state only; the actual UI exists here."
    local p=src:find(marker,1,true)
    if p then
        local head,tail=src:sub(1,p-1),src:sub(p)
        if tail:find("\\n",1,true) then tail=tail:gsub("\\n","\n");src=head..tail end
    end

    -- Normalize malformed serialized data before loadstring.
    local oldGet=[[local function get(path)
    local s=game:HttpGet(BASE..path)
    local f,e=loadstring(s,"@"..path); if not f then error(e) end
    return f()
end]]
    local newGet=[[local function get(path)
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
    return f()
end]]
    local ok
    src,ok=replaceOnce(src,oldGet,newGet)
    if not ok then error("data-loader patch point not found") end

    -- Absolutely no animation packs during SAFE BOOT.
    local a=src:find("-- Animation packs are mounted under one local Animations folder.",1,true)
    local b=a and src:find("-- Weather resources are local too.",a,true)
    if a and b then src=src:sub(1,a-1)..src:sub(b) end

    -- Optional billboards must not abort the runtime.
    local oldOwner='local ownerPack=get("data/owner_tag.lua");local ownerBy=mount(ownerPack,ownerStore);local ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui")'
    local newOwner='local ownerTemplate=nil;local okOwner,ownerPack=pcall(get,"data/owner_tag.lua");if okOwner and ownerPack then mount(ownerPack,ownerStore);ownerTemplate=ownerStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional owner_tag skipped: "..tostring(ownerPack)) end'
    src=select(1,replaceOnce(src,oldOwner,newOwner))
    local oldInfo='local infoPack=get("data/info_gui.lua");local infoBy=mount(infoPack,infoStore);local infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui")'
    local newInfo='local infoTemplate=nil;local okInfo,infoPack=pcall(get,"data/info_gui.lua");if okInfo and infoPack then mount(infoPack,infoStore);infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional info_gui skipped: "..tostring(infoPack)) end'
    src=select(1,replaceOnce(src,oldInfo,newInfo))

    -- Surface LocalScript failures on the visible diagnostics panel.
    local oldCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er); return end'
    local newCompile='if not fn then warn("[runtime compile]",inst:GetFullName(),er);pcall(function()local e=(getgenv and getgenv()) or _G;if e.__NULL_REPORT then e.__NULL_REPORT("LocalScript compile: "..inst:GetFullName().." | "..tostring(er)) end end);return end'
    src=select(1,replaceOnce(src,oldCompile,newCompile))
    local oldRuntime='local ok,e=pcall(fn); if not ok then warn("[runtime]",inst:GetFullName(),e) end'
    local newRuntime='local ok,e=pcall(fn);if not ok then warn("[runtime]",inst:GetFullName(),e);pcall(function()local g=(getgenv and getgenv()) or _G;if g.__NULL_REPORT then g.__NULL_REPORT("LocalScript runtime: "..inst:GetFullName().." | "..tostring(e)) end end) end'
    src=select(1,replaceOnce(src,oldRuntime,newRuntime))

    -- Expose heavy loaders but DO NOT call them automatically.
    local hook=[[runLocal()]]
    local heavy=[[

-- SAFE BOOT deliberately leaves the huge model/animation packs on GitHub.
-- They can be loaded later, one group at a time, after the UI is proven stable.
do
    local env=(getgenv and getgenv()) or _G
    env.__NULL_LOAD_RIG=function()
        print("[Null Protocol] manual rig load requested")
        local okRig,pack=pcall(get,"data/rig_assets.lua")
        if not okRig then warn("[Null Protocol] rig download/compile failed: "..tostring(pack));return false end
        mount(pack,RS)
        print("[Null Protocol] rig assets mounted")
        return true
    end
    env.__NULL_LOAD_ANIM=function(file)
        file=file or "anim_male.lua"
        local allowed={anim_male=true,anim_female=true,anim_bat=true,anim_other=true,anim_emotes=true}
        local stem=file:gsub("%.lua$","")
        if not allowed[stem] then error("invalid animation pack") end
        local root=RS:FindFirstChild("Animations")
        if not root then root=Instance.new("Folder");root.Name="Animations";root.Parent=RS end
        print("[Null Protocol] manual animation load: "..file)
        local okAnim,pack=pcall(get,"data/"..file)
        if not okAnim then warn("[Null Protocol] animation pack failed: "..tostring(pack));return false end
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

local ok,result=xpcall(function()
    stage("downloading core.lua")
    local src=game:HttpGet(BASE.."core.lua?cb="..tostring(math.floor(os.clock()*1000000)))
    stage("core downloaded: "..tostring(#src).." bytes")
    src=patchCore(src)
    stage("compiling safe core")
    local fn,er=loadstring(src,"NullProtocolSafeCore")
    if not fn then error("CORE COMPILE FAILED: "..tostring(er)) end
    local factory=fn()
    if type(factory)~="function" then error("core.lua did not return a function") end
    stage("starting SAFE runtime")
    local value=factory(BASE)

    -- Click probe. This does not replace the real button scripts; it only proves
    -- whether Roblox input reaches a GuiButton.
    local pg=plr:WaitForChild("PlayerGui")
    local seen=setmetatable({},{__mode="k"})
    local function probe(v)
        if seen[v] or not v:IsA("GuiButton") then return end
        seen[v]=true
        v.Activated:Connect(function()
            stage("CLICK: "..v:GetFullName())
        end)
    end
    for _,v in ipairs(pg:GetDescendants()) do probe(v) end
    pg.DescendantAdded:Connect(function(v) task.defer(probe,v) end)

    stage("SAFE BOOT READY | heavy assets paused | click a button")
    return value
end,function(e)
    local tr=tostring(e)
    pcall(function()if debug and debug.traceback then tr=debug.traceback(tr,2) end end)
    fail(tr)
    return tr
end)

if not ok then return nil,result end
return result
