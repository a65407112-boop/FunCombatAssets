-- Fun Combat external runtime loader
local BASE = getgenv and getgenv().FUNCOMBAT_RUNTIME_URL or _G.FUNCOMBAT_RUNTIME_URL
if type(BASE) ~= "string" or BASE == "" then
    error("Set FUNCOMBAT_RUNTIME_URL to the raw GitHub folder URL first")
end
if BASE:sub(-1) ~= "/" then BASE = BASE .. "/" end
local src = game:HttpGet(BASE .. "core.lua")
local fn,err = loadstring(src,"FunCombatRuntime")
if not fn then error(err) end
return fn()(BASE)
