-- Standalone local combat. Repository settings live only here.
local REPOSITORY={Owner="a65407112-boop",Name="FunCombatAssets",Branch="main"}
local Fetch=(function()
--@FETCH_MODULE@
end)()
local environment=type(getgenv)=="function" and getgenv() or _G
local KEY="__FunCombatPortable_v1"
local previous=environment[KEY]
if type(previous)=="table" and type(previous.destroy)=="function" then pcall(previous.destroy)end
local ctx={cancelled=false,reports={},config={Timeout=15},gender=type(previous)=="table" and previous.gender or nil,
    weaponChoice=type(previous)=="table" and previous.weaponChoice or nil}
environment[KEY]=ctx
function ctx.guiParent()
    if type(gethui)=="function"then local ok,p=pcall(gethui);if ok and typeof(p)=="Instance"then return p end end
    local player=game:GetService("Players").LocalPlayer
    return player and player:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
end
function ctx.destroy()
    if ctx.cancelled then return end;ctx.cancelled=true
    if ctx.cleanup then ctx.cleanup:destroy()end
    if environment[KEY]==ctx then environment[KEY]=nil end
end
function ctx.status(message)if ctx.ui then ctx.ui:status(message)end end
function ctx.report(message)
    message=tostring(message);ctx.reports[#ctx.reports+1]=message
    if #ctx.reports>40 then table.remove(ctx.reports,1)end
    warn("[Fun Combat Portable] "..message);ctx.status(message)
end
local requestFunction=request or http_request or (syn and syn.request)
local function requestText(url)
    if type(requestFunction)=="function"then
        local r=requestFunction({Url=url,Method="GET",Headers={["Cache-Control"]="no-cache"},Timeout=15})
        assert(type(r)=="table","HTTP request returned no response")
        local status=r.StatusCode or r.Status
        assert(r.Success~=false and (not status or status==200),"HTTP "..tostring(status).." at "..url)
        return r.Body
    end
    return game:HttpGet(url,true)
end
local fetch=Fetch.new({timeout=15,clock=tick,wait=wait,spawn=function(fn)coroutine.wrap(fn)()end,
    request=requestText,cancelled=function()return ctx.cancelled or environment[KEY]~=ctx end,hash=crypt and crypt.hash})
local prefix="https://raw.githubusercontent.com/"..REPOSITORY.Owner.."/"..REPOSITORY.Name.."/"
local function json(text,path)
    local ok,value=pcall(function()return game:GetService("HttpService"):JSONDecode(text)end)
    assert(ok and type(value)=="table","Invalid JSON at "..path..": "..tostring(value));return value
end
local function emergency(message)
    local ok=pcall(function()
        local gui=Instance.new("ScreenGui");gui.Name="FunCombatPortableError";gui.ResetOnSpawn=false;gui.Parent=ctx.guiParent()
        local box=Instance.new("TextBox");box.Size=UDim2.new(0,300,0,140);box.Position=UDim2.new(0,12,0,12)
        box.Text="Fun Combat Portable failed:\n"..message.."\nSelect this text to copy it.";box.ClearTextOnFocus=false;box.MultiLine=true;box.TextWrapped=true
        box.Font=Enum.Font.SourceSans;box.TextSize=14;box.TextColor3=Color3.new(1,1,1);box.BackgroundColor3=Color3.fromRGB(32,36,44);box.Parent=gui
        local close=Instance.new("TextButton");close.Text="Close";close.Position=UDim2.new(0,12,0,154);close.Size=UDim2.new(0,90,0,30);close.Parent=gui
        close.Activated:Connect(function()gui:Destroy()end)
    end)
    if not ok then warn("[Fun Combat Portable] "..message)end
end
local ok,failure=pcall(function()
    assert(type(loadstring)=="function","Executor must provide loadstring")
    local players=game:GetService("Players");local deadline=tick()+15
    while not players.LocalPlayer and tick()<deadline do wait(0.05)end
    assert(players.LocalPlayer,"LocalPlayer did not become available within 15s")
    local manifestPath="portable/manifest.json"
    local portable=json(fetch:get(prefix..REPOSITORY.Branch.."/"..manifestPath),manifestPath)
    assert(portable.version==2 and portable.mode=="local-only" and portable.executeButton==false,"Unsupported portable manifest; fetch a fresh portable loader")
    assert(type(portable.sharedCommit)=="string" and #portable.sharedCommit==40,"Missing immutable original-resource commit")
    ctx.portableManifest=portable
    local base=prefix..REPOSITORY.Branch.."/"
    local sharedBase=prefix..portable.sharedCommit.."/"
    local function own(path)
        local metadata=assert(portable.files[path],"Portable file missing from manifest: "..path)
        return fetch:get(base..path,metadata)
    end
    ctx.manifest=json(fetch:get(sharedBase.."manifest.json",portable.sharedManifest),"manifest.json")
    ctx.manifest.buildId=portable.buildId -- isolate local native import cache filenames
    function ctx.http(path)
        local metadata=assert(ctx.manifest.files[path],"Original resource missing from manifest: "..path)
        return fetch:get(sharedBase..path,metadata)
    end
    function ctx.json(path)return json(ctx.http(path),path)end
    ctx.config=json(own("portable/config.json"),"portable/config.json")
    assert(ctx.config.Timeout>=1 and ctx.config.Timeout<=30,"Invalid portable timeout")
    ctx.catalog=ctx.json("config/assets.json")
    assert(ctx.catalog.nativeMode=="external","Portable requires the external-resource catalog")
    ctx.modules={}
    local function compile(body,name)
        local fn,why=loadstring(body,"@FunCombat/portable/"..name)
        assert(type(fn)=="function","Module syntax failed: "..name..": "..tostring(why));return fn()
    end
    for _,name in ipairs(portable.modules)do ctx.modules[name]=compile(own("portable/"..name..".lua"),name)end
    local shared={}
    for _,name in ipairs(portable.sharedModules)do shared[name]=compile(ctx.http("client/"..name..".lua"),"shared/"..name)end
    ctx.cleanup=shared.cleanup(ctx)
    ctx.network=ctx.modules.bus.new(tick,ctx.report);ctx.cleanup:add(ctx.network)
    ctx.core=ctx.modules.core.new(ctx.config)
    local function view(r)
        if not r or not r.character then return nil end
        return {character=r.character,weapon=r.weapon,downed=r.downed,ragdolled=r.ragdolled,
            carrying=r.carrying and r.carrying.character,carriedBy=r.carriedBy and r.carriedBy.character,
            gender=r.gender,displayName=r.displayName,userId=r.userId,health=r.health,maxHealth=100,
            kills=r.kills,busy=r.busy,ownerTag=r.userId==ctx.config.CreatorUserId}
    end
    ctx.state={}
    function ctx.state:get(character)return view(ctx.avatars and ctx.avatars.byModel[character])end
    function ctx.state:all()local out={};for _,r in pairs(ctx.core.records)do if r.character then out[r.character]=view(r)end end;return out end
    function ctx.state:onChanged(fn)return ctx.core:onChanged(function(r)fn(view(r))end)end
    ctx.assets=shared.assets(ctx);ctx.animations=shared.animations(ctx)
    -- Warm original resources before input becomes available, avoiding hit-time HTTP.
    local original=ctx.assets:clone("weapons/"..ctx.config.DefaultWeapon);original:Destroy()
    for _,key in ipairs(portable.preloadAnimations)do ctx.animations:preload(key)end
    for _,key in ipairs({"audio/Default","audio/Heavy","audio/Carry","audio/Uncarry"})do local s=ctx.assets:clone(key);s:Destroy()end
    for _,key in ipairs({"effects/dash_limbs","effects/dash_smoke"})do local s=ctx.assets:clone(key);s:Destroy()end
    ctx.avatars=ctx.modules.avatars(ctx)
    ctx.weapons=ctx.modules.weapons(ctx);ctx.audio=shared.audio(ctx)
    ctx.locomotion=ctx.modules.locomotion.new(ctx)
    ctx.dashEffects=ctx.modules.dash_effects(ctx)
    ctx.dash=ctx.modules.dash(ctx)
    ctx.controller=ctx.modules.controller(ctx);ctx.ui=ctx.modules.ui(ctx)
    assert(not ctx.cancelled and environment[KEY]==ctx,"Portable startup cancelled by a newer execution")
    ctx.initialized=true;ctx.status(ctx.gender and "Ready" or "Choose your gender")
    print("[Fun Combat Portable] Ready; "..portable.buildId..". No server protocol is used.")
end)
if not ok then
    local interrupted=ctx.cancelled or environment[KEY]~=ctx
    ctx.destroy()
    if not interrupted then emergency(tostring(failure))end
end
return ctx
