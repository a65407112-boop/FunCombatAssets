-- Null Protocol stable entrypoint
local url = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader_v5.lua?cb=" .. tostring(os.clock())
local src = game:HttpGet(url)
local fn, err = loadstring(src, "NullProtocolStableEntrypoint")
if not fn then
    error("Null Protocol entrypoint compile failed: " .. tostring(err))
end
return fn()
