-- Null Protocol / Fun Combat external runtime loader
local BASE = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"

local function stage(name)
    print("[Null Protocol] " .. name)
end

local function insertAfter(src, needle, text)
    local p = src:find(needle, 1, true)
    if not p then return nil end
    local after = p + #needle
    return src:sub(1, after - 1) .. text .. src:sub(after)
end

local function patchCore(src)
    -- Repair the malformed tail from the previous exporter build.
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

    -- Remove the original early animation block. It downloaded ~13 MB before
    -- PlayerGui even existed, making a working load look like a dead script.
    local animStart = "-- Animation packs are mounted under one local Animations folder."
    local animEnd = "-- Weather resources are local too."
    local a = src:find(animStart, 1, true)
    local b = a and src:find(animEnd, a, true)
    if a and b then
        src = src:sub(1, a - 1) .. src:sub(b)
        stage("deferred heavy animation packs")
    end

    local guiNeedle = 'local gui=get("data/starter_gui.lua"); local guiBy=mount(gui,plr:WaitForChild("PlayerGui"))'
    local afterGui = [[
print("[Null Protocol] GUI tree mounted")

-- Large model/morph/visual tree removed from the physical place.
do
    print("[Null Protocol] loading rig_assets.lua")
    local okRig,rigPack=pcall(get,"data/rig_assets.lua")
    if okRig and rigPack then
        mount(rigPack,RS)
        print("[Null Protocol] rig assets mounted")
    else
        warn("[Null Protocol] rig_assets failed: "..tostring(rigPack))
    end
end

-- Load the heavy keyframe trees only after GUI and model data are available.
do
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
    end
end
]]
    local patched = insertAfter(src, guiNeedle, "\n" .. afterGui .. "\n")
    if not patched then
        error("core patch point after starter_gui was not found")
    end
    src = patched

    -- Tiny admin thumbnail asset was also physically removed.
    if not src:find('get("data/admin_thumbnail.lua")', 1, true) then
        local rtNeedle = 'local rtAssets=Instance.new("Folder");rtAssets.Name="__rt_assets";rtAssets.Parent=RS'
        local addThumb = '\nlocal adminThumbPack=get("data/admin_thumbnail.lua"); mount(adminThumbPack,rtAssets)\n'
        local p = insertAfter(src, rtNeedle, addThumb)
        if p then src = p end
    end

    return src
end

local ok, result = xpcall(function()
    stage("downloading core.lua")
    local src = game:HttpGet(BASE .. "core.lua")
    stage("core downloaded (" .. tostring(#src) .. " bytes)")

    src = patchCore(src)

    local fn, err = loadstring(src, "NullProtocolRuntime")
    if not fn then
        error("CORE COMPILE FAILED: " .. tostring(err))
    end

    stage("core compiled")
    local value = fn()(BASE)
    stage("runtime mounted")
    return value
end, function(err)
    local trace = debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
    warn("[Null Protocol] RUNTIME ERROR:\n" .. trace)
    return trace
end)

if not ok then
    return nil, result
end
return result
