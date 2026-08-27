-- Fun Combat external runtime loader

local BASE =
    "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"

local src = game:HttpGet(BASE .. "core.lua")

local fn, err = loadstring(src, "FunCombatRuntime")
if not fn then
    error(err)
end

return fn()(BASE)
