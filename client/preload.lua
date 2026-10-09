-- Warm original presentation resources before any combat input is installed.
-- Only presentation is prepared here; the server still chooses every action.
return function(ctx)
    local scope = ctx.cleanup:scope()
    local alive, finished = true, 0
    scope:add(function() alive = false end)
    local jobs, failures = {}, {}
    local module = {ready = false}
    if type(ctx.assets.checkCapabilities)=="function" then ctx.assets:checkCapabilities() end
    for key in pairs(ctx.catalog.packages) do jobs[#jobs + 1] = {kind = "asset", key = key} end
    for key in pairs(ctx.catalog.animations) do jobs[#jobs + 1] = {kind = "animation", key = key} end
    table.sort(jobs, function(a, b) return a.kind .. "/" .. a.key < b.kind .. "/" .. b.key end)
    local cursor = 0
    local workers = math.min(6, #jobs)
    local deadline = (ctx.started or tick()) + (ctx.config.BootstrapTimeout or 300)
    assert(not ctx.cancelled and not scope.dead, "Resource warm-up cancelled")
    for _ = 1, workers do
        coroutine.wrap(function()
            while alive and not ctx.cancelled and not scope.dead and #failures == 0 and tick() < deadline do
                cursor = cursor + 1
                local job = jobs[cursor]
                if not job then break end
                local ok, why = pcall(function()
                    if job.kind == "animation" then ctx.animations:preload(job.key)
                    else
                        local asset = ctx.assets:clone(job.key)
                        asset:Destroy()
                    end
                end)
                if not ok then
                    failures[#failures + 1] = job.kind .. " " .. job.key .. ": " .. tostring(why)
                end
            end
            finished = finished + 1
        end)()
    end
    while finished < workers and #failures == 0 and not ctx.cancelled and not scope.dead and tick() < deadline do wait(0.05) end
    assert(not ctx.cancelled and not scope.dead, "Resource warm-up cancelled")
    assert(#failures == 0, "Original resource warm-up failed: " .. table.concat(failures, "; "))
    assert(finished == workers and cursor >= #jobs, "Original resource warm-up exceeded the bootstrap deadline")

    -- Roblox still downloads hosted mesh/texture/sound/animation content. Give
    -- it a bounded head start too, rather than first requesting it on a swing.
    local content, seen = {}, {}
    local function add(value)
        if value and not seen[value] then seen[value] = true; content[#content + 1] = value end
    end
    for _, root in pairs(ctx.assets.cache) do
        local objects = root:GetDescendants(); objects[#objects + 1] = root
        for _, object in ipairs(objects) do
            if object:IsA("Sound") or object:IsA("MeshPart") or object:IsA("SpecialMesh") or object:IsA("Decal")
                or object:IsA("Texture") or object:IsA("ImageLabel") or object:IsA("ImageButton")
                or object:IsA("Animation") or object:IsA("SurfaceAppearance") then add(object) end
        end
    end
    for _, entry in pairs(ctx.catalog.hostedAnimations or {}) do add(entry.AnimationId) end
    for _, entry in pairs(ctx.json("assets/animations/locomotion.json")) do add(entry.AnimationId) end
    local done = #content == 0
    if not done then
        coroutine.wrap(function()
            local ok, why = pcall(function()
                game:GetService("ContentProvider"):PreloadAsync(content, function(asset, status)
                    local value=tostring(status)
                    if alive and (value:find("Failure") or value:find("TimedOut")) then
                        ctx.report("Hosted content unavailable: " .. tostring(asset) .. " (" .. value .. ")")
                    end
                end)
            end)
            if not ok and alive then ctx.report("Hosted content preload: " .. tostring(why)) end
            done = true
        end)()
    end
    local contentDeadline = math.min(deadline, tick() + ctx.config.Timeout)
    while not done and not ctx.cancelled and not scope.dead and tick() < contentDeadline do wait(0.05) end
    assert(not ctx.cancelled and not scope.dead, "Resource warm-up cancelled")
    if not done then ctx.report("Hosted content preload exceeded " .. ctx.config.Timeout .. " seconds; Roblox will continue loading it. Asset availability has not been confirmed.") end
    module.ready = true
    function module:destroy() scope:destroy() end
    return module
end
