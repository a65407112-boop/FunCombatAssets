-- Null Protocol / Fun Combat external runtime loader
local BASE = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"

local function stage(name)
    print("[Null Protocol] " .. name)
end

local function patchCore(src)
    -- A previous build accidentally wrote literal \\n sequences into the final
    -- server-private presentation block. Repair only that tail so normal
    -- escaped strings elsewhere in core.lua are left untouched.
    local marker = "-- Server-private presentation is represented by state only; the actual UI exists here."
    local pos = src:find(marker, 1, true)
    if pos then
        local head = src:sub(1, pos - 1)
        local tail = src:sub(pos)
        if tail:find("\\n", 1, true) then
            tail = tail:gsub("\\n", "\n")
            src = head .. tail
            stage("repaired core tail")
        end
    end

    -- rig_assets.lua contains the large model/morph/visual tree that was
    -- physically removed from the place. The old core forgot to mount it.
    if not src:find('get("data/rig_assets.lua")', 1, true) then
        local needle = "local coreBy=mount(core,RS)"
        local p = src:find(needle, 1, true)
        if not p then
            error("core patch point for rig_assets was not found")
        end
        local after = p + #needle
        local inject = '\nlocal rigPack=get("data/rig_assets.lua"); mount(rigPack,RS)\n'
        src = src:sub(1, after - 1) .. inject .. src:sub(after)
        stage("enabled rig_assets")
    end

    -- Keep the tiny admin thumbnail asset available locally too. It is
    -- intentionally mounted under the runtime-only asset folder.
    if not src:find('get("data/admin_thumbnail.lua")', 1, true) then
        local needle = 'local rtAssets=Instance.new("Folder");rtAssets.Name="__rt_assets";rtAssets.Parent=RS'
        local p = src:find(needle, 1, true)
        if p then
            local after = p + #needle
            local inject = '\nlocal adminThumbPack=get("data/admin_thumbnail.lua"); mount(adminThumbPack,rtAssets)\n'
            src = src:sub(1, after - 1) .. inject .. src:sub(after)
            stage("enabled admin thumbnail")
        end
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
