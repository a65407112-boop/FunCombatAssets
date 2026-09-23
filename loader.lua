-- Upload the contents of GitHub/ to this repository before running this loader.
-- This is the ONLY repository configuration location. No game assets are fetched
-- from a previous project: the manifest must match this reconstruction build.
local CONFIG = {
    Owner = "a65407112-boop",
    Repository = "FunCombatAssets",
    Branch = "main",
    Timeout = 20,
    Verbose = false,
    AnimationClock = "source" -- original 60 Hz playback; "keyframes" uses authored time
}

assert(type(loadstring) == "function", "Fun Combat requires an executor with loadstring")
local environment = (type(getgenv) == "function" and getgenv()) or _G
local slot = "FunCombat_ExternalRuntime"
local previous = environment[slot]
if type(previous) == "table" then
    previous.cancelled = true
    if type(previous.destroy) == "function" then pcall(function() previous:destroy() end) end
end
local ctx = {config = CONFIG, modules = {}, loading = {}, cancelled = false, reports = {}}
environment[slot] = ctx
function ctx:destroy()
    self.cancelled = true
    if self.cleanup then self.cleanup:destroy() end
    if environment[slot] == self then environment[slot] = nil end
end
function ctx.report(message)
    message = tostring(message)
    if not ctx.reports[message] then
        ctx.reports[message] = true
        warn("[Fun Combat] " .. message)
    end
end
local httpService = game:GetService("HttpService")
local base = "https://raw.githubusercontent.com/" .. CONFIG.Owner .. "/" .. CONFIG.Repository .. "/" .. CONFIG.Branch .. "/"
local requester = request or http_request or (syn and syn.request)
local function fetch(url)
    if type(requester) == "function" then
        local response = requester({Url = url, Method = "GET"})
        assert(type(response) == "table" and response.StatusCode == 200,
            "HTTP " .. tostring(type(response) == "table" and response.StatusCode or "no response"))
        assert(type(response.Body) == "string", "HTTP returned no body")
        return response.Body
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    assert(ok and type(body) == "string", "Executor has no usable HTTP capability: " .. tostring(body))
    return body
end
function ctx.http(path)
    assert(type(path) == "string" and not path:find("%.%.") and not path:find("://"), "Invalid repository path")
    local lastError
    for attempt = 1, 2 do
        assert(not ctx.cancelled, "Initialization cancelled by a newer loader")
        local done, result, failure = false, nil, nil
        coroutine.wrap(function()
            local ok, data = pcall(fetch, base .. path)
            if ok then result = data else failure = data end
            done = true
        end)()
        local deadline = tick() + CONFIG.Timeout
        repeat wait(0.05) until done or tick() >= deadline or ctx.cancelled
        if done and not failure and type(result) == "string" and #result > 0 then
            assert(#result <= 20 * 1024 * 1024, "Repository resource exceeds 20 MiB: " .. path)
            assert(not ctx.cancelled, "Initialization cancelled")
            return result
        end
        lastError = failure or "HTTP timeout"
        if attempt == 1 then wait(0.25) end
    end
    error("Failed to load " .. path .. ": " .. tostring(lastError) .. ". Upload this build's GitHub folder and check CONFIG at the top of loader.lua.")
end
function ctx.json(path)
    local ok, value = pcall(function() return httpService:JSONDecode(ctx.http(path)) end)
    assert(ok and type(value) == "table", "Invalid JSON at " .. path .. ": " .. tostring(value))
    return value
end
function ctx.load(name)
    assert(not ctx.cancelled, "Initialization cancelled")
    if ctx.modules[name] then return ctx.modules[name] end
    assert(not ctx.loading[name], "Circular runtime dependency: " .. name)
    assert(ctx.allowed[name], "Undeclared runtime module: " .. name)
    ctx.loading[name] = true
    local chunk, why = loadstring(ctx.http("client/" .. name .. ".lua"), "@FunCombat/client/" .. name)
    assert(chunk, "Compile failed for " .. name .. ": " .. tostring(why))
    local factory = chunk()
    assert(type(factory) == "function", "Invalid module factory: " .. name)
    local result = factory(ctx)
    assert(type(result) == "table", "Module did not initialize: " .. name)
    if ctx.cancelled then
        if type(result.destroy) == "function" then pcall(function() result:destroy() end) end
        error("Initialization cancelled")
    end
    ctx.modules[name] = result; ctx[name] = result; ctx.loading[name] = nil
    if name == "networking" then ctx.network = result end
    return result
end
local ok, failure = pcall(function()
    ctx.manifest = ctx.json("manifest.json")
    assert(ctx.manifest.project == "FunCombat_ExecutorSide_Combat" and ctx.manifest.protocolVersion == 2,
        "Repository contains a different Fun Combat build")
    ctx.catalog = ctx.json("config/assets.json")
    ctx.identifiers = ctx.json("config/identifiers.json")
    assert(ctx.catalog.sourceSha256 == ctx.manifest.sourceSha256, "Manifest and assets belong to different source versions")
    ctx.allowed = {}
    for _, name in ipairs(ctx.manifest.modules) do ctx.allowed[name] = true end
    for _, name in ipairs(ctx.manifest.modules) do
        if CONFIG.Verbose then print("[Fun Combat] Initializing " .. name) end
        ctx.load(name)
    end
    assert(not ctx.cancelled, "Initialization cancelled")
    print("[Fun Combat] External combat runtime initialized. Engine asset warnings, if any, are above.")
end)
if not ok then
    ctx:destroy()
    local message = "[Fun Combat] Initialization failed: " .. tostring(failure)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Fun Combat", Text = message, Duration = 12}) end)
    error(message)
end
return ctx
