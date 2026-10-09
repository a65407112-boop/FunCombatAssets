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
    ,BootstrapTimeout = 300
}

assert(type(loadstring) == "function", "Fun Combat requires an executor with loadstring")
local environment = (type(getgenv) == "function" and getgenv()) or _G
local slot = "FunCombat_ExternalRuntime"
local errorSlot = slot .. "_ErrorGUI"
if environment[errorSlot] then
    pcall(function() environment[errorSlot]:Destroy() end)
    environment[errorSlot] = nil
end
local previous = environment[slot]
if type(previous) == "table" then
    previous.cancelled = true
    if type(previous.destroy) == "function" then pcall(function() previous:destroy() end) end
end
local ctx = {config = CONFIG, modules = {}, loading = {}, cancelled = false, reports = {}, files = {}, started=tick()}
environment[slot] = ctx
-- Bootstrap failures cannot depend on downloading an external UI module.
-- Keep the full error selectable and scrollable even before manifest loading.
local function showFailure(message)
    local gui
    local ok = pcall(function()
        local player=game:GetService("Players").LocalPlayer
        local parent=player and player:FindFirstChildOfClass("PlayerGui")
        if not parent then parent=game:GetService("CoreGui") end
        gui=Instance.new("ScreenGui");gui.Name="FunCombat_LoadError";gui.ResetOnSpawn=false
        local frame=Instance.new("Frame");frame.Name="Error";frame.Size=UDim2.new(0.8,0,0.65,0)
        frame.Position=UDim2.new(0.1,0,0.15,0);frame.BackgroundColor3=Color3.fromRGB(24,24,30);frame.Parent=gui
        local title=Instance.new("TextLabel");title.Size=UDim2.new(1,-110,0,36);title.Position=UDim2.new(0,12,0,0)
        title.BackgroundTransparency=1;title.Text="Fun Combat could not initialize";title.TextColor3=Color3.fromRGB(255,220,220)
        title.Font=Enum.Font.SourceSansBold;title.TextSize=20;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=frame
        local close=Instance.new("TextButton");close.Name="Close";close.Text="Close";close.Size=UDim2.new(0,70,0,28)
        close.Position=UDim2.new(1,-82,0,4);close.Parent=frame
        close.MouseButton1Click:Connect(function()
            if environment[errorSlot]==gui then environment[errorSlot]=nil end
            gui:Destroy()
        end)
        local scroll=Instance.new("ScrollingFrame");scroll.Size=UDim2.new(1,-24,1,-84)
        scroll.Position=UDim2.new(0,12,0,40);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Parent=frame
        local text=Instance.new("TextBox");text.Name="Details";text.Text=message;text.ClearTextOnFocus=false
        text.MultiLine=true;text.TextWrapped=true;text.BackgroundTransparency=1;text.TextColor3=Color3.fromRGB(245,245,245)
        text.Font=Enum.Font.Code;text.TextSize=14;text.TextXAlignment=Enum.TextXAlignment.Left;text.TextYAlignment=Enum.TextYAlignment.Top
        pcall(function() text.TextEditable=false end)
        text.Parent=scroll
        local function size()
            local height=40+math.ceil(#message/35)*20
            pcall(function()
                height=game:GetService("TextService"):GetTextSize(message,14,Enum.Font.Code,
                    Vector2.new(math.max(180,scroll.AbsoluteSize.X-20),1000000)).Y+24
            end)
            text.Size=UDim2.new(1,-20,0,height);scroll.CanvasSize=UDim2.new(0,0,0,height)
        end
        scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
        if type(setclipboard)=="function" then
            local copy=Instance.new("TextButton");copy.Name="Copy";copy.Text="Copy full error";copy.Size=UDim2.new(0,160,0,28)
            copy.Position=UDim2.new(0,12,1,-36);copy.Parent=frame
            copy.MouseButton1Click:Connect(function() pcall(setclipboard,message) end)
        end
        gui.Parent=parent;size();environment[errorSlot]=gui
    end)
    if not ok and gui then gui:Destroy() end
end
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
    if ctx.files[path] then return ctx.files[path] end
    local lastError
    for attempt = 1, 2 do
        assert(not ctx.cancelled, "Initialization cancelled by a newer loader")
        assert(tick()-ctx.started<CONFIG.BootstrapTimeout or ctx.initialized,"Bootstrap exceeded "..CONFIG.BootstrapTimeout.." seconds at "..path)
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
            local expected=ctx.manifest and ctx.manifest.files[path]
            if expected then
                assert(#result==expected.bytes,"Repository file size differs from manifest: "..path)
                local a,b=1,0
                for i=1,#result do a=(a+string.byte(result,i))%65521;b=(b+a)%65521 end
                assert(b*65536+a==expected.adler32,"Repository checksum differs from manifest: "..path.."; a deployment may be incomplete")
            elseif ctx.manifest then error("File is absent from manifest: "..path) end
            ctx.files[path]=result
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
    for _,dependency in ipairs(ctx.manifest.dependencies[name] or {}) do ctx.load(dependency) end
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
    assert(ctx.manifest.project == "FunCombat_ExecutorSide_Combat" and (ctx.manifest.protocolVersion == 5 or ctx.manifest.protocolVersion == 5),
        "Repository contains a different Fun Combat build")
    ctx.catalog = ctx.json("config/assets.json")
    ctx.identifiers = ctx.json("config/identifiers.json")
    ctx.protocol = ctx.json("config/protocol.json")
    assert(ctx.protocol.version==ctx.manifest.protocolVersion and ctx.protocol.buildId==ctx.manifest.buildId,"Manifest and protocol build IDs differ")
    assert(ctx.catalog.sourceSha256 == ctx.manifest.sourceSha256, "Manifest and assets belong to different source versions")
    ctx.allowed = {}
    for _, name in ipairs(ctx.manifest.modules) do ctx.allowed[name] = true end
    for _, name in ipairs(ctx.manifest.modules) do
        if CONFIG.Verbose then print("[Fun Combat] Initializing " .. name) end
        ctx.load(name)
    end
    assert(not ctx.cancelled, "Initialization cancelled")
    ctx.initialized=true
    print("[Fun Combat] External combat runtime initialized. Engine asset warnings, if any, are above.")
end)
if not ok then
    local current=environment[slot]==ctx
    ctx:destroy()
    local message = "[Fun Combat] Initialization failed: " .. tostring(failure)
    warn(message)
    if current then
        showFailure(message)
        pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Fun Combat", Text = "Initialization failed. The full error is in the error window and console.", Duration = 12}) end)
    end
    error(message)
end
return ctx
