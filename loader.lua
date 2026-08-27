-- FunCombat / Null Protocol stable client entrypoint v2.1
-- Hotfix: StarterPlayer.rbxm is intentionally NOT runtime-packed. Xeno's pure-Lua
-- LZ4 repacker can stall on that file. We load its first root (StarterPlayerScripts)
-- and use the built-in R6/character fallbacks for the other two roots.
local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/runtime/"
local parts={}
for i=1,7 do
    local url=BASE.."v2_part"..i..".lua?cb="..tostring(os.clock()).."_"..i
    local ok,src=pcall(function() return game:HttpGet(url) end)
    if not ok or type(src)~="string" then
        error("FunCombat v2.1 download failed at part "..i..": "..tostring(src))
    end
    if i==2 then
        src=src:gsub('%["StarterPlayer%.rbxm"%]%s*=%s*true,%s*','')
    end
    parts[#parts+1]=src
end
local source=table.concat(parts)
local fn,err=loadstring(source,"FunCombatNativeRuntimeV21")
if not fn then
    error("FunCombat v2.1 compile failed: "..tostring(err))
end
return fn()
