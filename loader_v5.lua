-- Null Protocol runtime v8 entry
-- Run the pinned v7 gameplay/runtime bridge, then apply deterministic menu presentation fixes.

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/"

local function run(url,name)
    local src=game:HttpGet(url.."?cb="..tostring(os.clock()))
    local fn,err=loadstring(src,name)
    if not fn then error(name.." compile failed: "..tostring(err)) end
    return fn()
end

local ok,result=xpcall(function()
    local value=run(BASE.."fde9edaeb1b833374a7b42ec0caa0446e460416b/loader_v5.lua","NullProtocolV7Base")
    run(BASE.."6e7550ef6985ca9fae6802454c98735b2b1628fe/ui_hotfix_v8.lua","NullProtocolUIV8")
    print("[Null Protocol] v8 menu hotfix active")
    return value
end,function(e)
    local msg=tostring(e)
    warn("[Null Protocol v8] "..msg)
    pcall(function()
        local pg=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        local g=pg and pg:FindFirstChild("__NPBootstrap")
        local l=g and g:FindFirstChildWhichIsA("TextLabel",true)
        if l then
            l.Text="Null Protocol v8 ERROR: "..msg
            l.BackgroundColor3=Color3.fromRGB(100,20,20)
        end
    end)
    return msg
end)

return ok and result or nil
