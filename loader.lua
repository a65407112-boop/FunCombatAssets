-- Null Protocol / Fun Combat external runtime loader
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local diagGui
local diagLabel
pcall(function()
    local pg = plr and plr:WaitForChild("PlayerGui", 10)
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
    frame.Name = "Panel"
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0, 18)
    frame.Size = UDim2.new(0, 620, 0, 84)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Parent = diagGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    diagLabel = Instance.new("TextLabel")
    diagLabel.Name = "Status"
    diagLabel.BackgroundTransparency = 1
    diagLabel.Position = UDim2.new(0, 14, 0, 8)
    diagLabel.Size = UDim2.new(1, -28, 1, -16)
    diagLabel.Font = Enum.Font.Code
    diagLabel.TextSize = 16
    diagLabel.TextWrapped = true
    diagLabel.TextXAlignment = Enum.TextXAlignment.Left
    diagLabel.TextYAlignment = Enum.TextYAlignment.Center
    diagLabel.TextColor3 = Color3.new(1,1,1)
    diagLabel.Text = "Null Protocol: loader started"
    diagLabel.Parent = frame
end)

local function stage(name)
    print("[Null Protocol] " .. name)
    pcall(function()
        if diagLabel then diagLabel.Text = "Null Protocol: " .. name end
    end)
end

local function fail(msg)
    local text = tostring(msg)
    warn("[Null Protocol] " .. text)
    pcall(function()
        if diagLabel then
            diagLabel.TextColor3 = Color3.fromRGB(255, 125, 125)
            diagLabel.Text = "Null Protocol ERROR:\n" .. text
        end
    end)
end

local BASE = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"

local function insertAfter(src, needle, text)
    local p = src:find(needle, 1, true)
    if not p then return nil end
    local after = p + #needle
    return src:sub(1, after - 1) .. text .. src:sub(after)
end

local function replaceOnce(src, needle, repl)
    local p = src:find(needle, 1, true)
    if not p then return src, false end
    return src:sub(1, p - 1) .. repl .. src:sub(p + #needle), true
end

local function patchCore(src)
    stage("patching core")

    local marker = "-- Server-private presentation is represented by state only; the actual UI exists here."
    local pos = src:find(marker, 1, true)
    if pos then
        local head = src:sub(1, pos - 1)
        local tail = src:sub(pos)
        if tail:find("\\n", 1, true) then
            tail = tail:gsub("\\n", "\n")
            src = head .. tail
            stage("repaired malformed core tail")
        end
    end

    local oldGet = [[local function get(path)
    local s=game:HttpGet(BASE..path)
    local f,e=loadstring(s,"@"..path); if not f then error(e) end
    return f()
end]]

    local newGet = [[local function get(path)
    print("[Null Protocol] downloading "..path)
    local s=game:HttpGet(BASE..path)

    -- Repair table keys emitted as [[[token]]]=value.
    local fixed,keyFixes=s:gsub("%[%[%[([%w_%-]+)%]%]%]%s*=", '["%1"]=')

    -- Repair property string values whose intended text ends in ']'.
    -- Example: {[[Text]],[[N/A [N/A]]]}, is invalid because the exporter
    -- used raw [[...]] strings. Convert just this unambiguous property form
    -- to a quoted Lua string.
    local valueFixes=0
    fixed,valueFixes=fixed:gsub("({%[%[[%w_]+%]%],)%[%[(.-)%]%]%](},)", function(prefix,body,suffix)
        return prefix..string.format("%q",body.."]")..suffix
    end)

    local total=keyFixes+valueFixes
    if total>0 then
        print("[Null Protocol] repaired "..tostring(total).." serialized strings in "..path)
    end

    local f,e=loadstring(fixed,"@"..path)
    if not f then error("DATA COMPILE FAILED "..path..": "..tostring(e)) end
    return f()
end]]

    local gp = src:find(oldGet, 1, true)
    if not gp then
        error("data-loader patch point not found")
    end
    src = src:sub(1, gp - 1) .. newGet .. src:sub(gp + #oldGet)
    stage("enabled serialized-data repair")

    local animStart = "-- Animation packs are mounted under one local Animations folder."
    local animEnd = "-- Weather resources are local too."
    local a = src:find(animStart, 1, true)
    local b = a and src:find(animEnd, a, true)
    if a and b then
        src = src:sub(1, a - 1) .. src:sub(b)
        stage("deferred animation packs")
    end

    if not src:find('get("data/rig_assets.lua")', 1, true) then
        local needle = "local coreBy=mount(core,RS)"
        local text = [[

print("[Null Protocol] loading rig_assets.lua")
local okRig,rigPack=pcall(get,"data/rig_assets.lua")
if okRig and rigPack then
    mount(rigPack,RS)
    print("[Null Protocol] rig assets mounted")
else
    warn("[Null Protocol] rig_assets failed: "..tostring(rigPack))
end
]]
        local patched = insertAfter(src, needle, text)
        if not patched then error("rig_assets patch point not found") end
        src = patched
    end

    -- info_gui is only a local overhead billboard. It must never abort the
    -- entire runtime if an exported label contains awkward bracket text.
    local oldInfo = 'local infoPack=get("data/info_gui.lua");local infoBy=mount(infoPack,infoStore);local infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui")'
    local newInfo = 'local infoTemplate=nil;local okInfo,infoPack=pcall(get,"data/info_gui.lua");if okInfo and infoPack then mount(infoPack,infoStore);infoTemplate=infoStore:FindFirstChildWhichIsA("BillboardGui") else warn("[Null Protocol] optional info_gui skipped: "..tostring(infoPack)) end'
    src = select(1, replaceOnce(src, oldInfo, newInfo))

    local runNeedle = "runLocal()"
    local runPos = src:find(runNeedle, 1, true)
    if not runPos then error("runLocal patch point not found") end
    local afterRun = runPos + #runNeedle
    local deferred = [[

-- Heavy animation data is intentionally loaded after the initial local UI has started.
task.spawn(function()
    local animRoot=RS:FindFirstChild("Animations")
    if not animRoot then animRoot=Instance.new("Folder");animRoot.Name="Animations";animRoot.Parent=RS end
    local animFiles={"anim_male.lua","anim_female.lua","anim_bat.lua","anim_other.lua","anim_emotes.lua"}
    for _,f in ipairs(animFiles) do
        print("[Null Protocol] loading "..f)
        local okAnim,pack=pcall(get,"data/"..f)
        if okAnim and pack then
            mount(pack,animRoot)
            print("[Null Protocol] mounted "..f)
        else
            warn("[Null Protocol] "..f.." failed: "..tostring(pack))
        end
        task.wait()
    end
end)
]]
    src = src:sub(1, afterRun - 1) .. deferred .. src:sub(afterRun)

    return src
end

local ok, result = xpcall(function()
    stage("downloading core.lua")
    local url = BASE .. "core.lua?cb=" .. tostring(math.floor(os.clock()*1000000))
    local src = game:HttpGet(url)
    stage("core downloaded: " .. tostring(#src) .. " bytes")

    src = patchCore(src)

    stage("compiling core")
    local fn, err = loadstring(src)
    if not fn then error("CORE COMPILE FAILED: " .. tostring(err)) end

    stage("starting runtime")
    local factory = fn()
    if type(factory) ~= "function" then
        error("core.lua did not return a function")
    end
    local value = factory(BASE)
    stage("runtime mounted")

    task.delay(2, function()
        pcall(function()
            if diagGui then diagGui:Destroy() end
        end)
    end)
    return value
end, function(err)
    local trace = tostring(err)
    pcall(function()
        if debug and debug.traceback then trace = debug.traceback(trace, 2) end
    end)
    fail(trace)
    return trace
end)

if not ok then return nil, result end
return result
