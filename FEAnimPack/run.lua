local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/"
local src=game:HttpGet(BASE.."loader.lua")
src=src:gsub('BASE %.%. "animations%.lua"','BASE .. "animations_runtime.lua"')
return loadstring(src)()
