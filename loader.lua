-- FunCombat / Null Protocol stable client entrypoint v2
local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/runtime/"
local parts={}
for i=1,7 do
    local url=BASE.."v2_part"..i..".lua?cb="..tostring(os.clock()).."_"..i
    local ok,src=pcall(function() return game:HttpGet(url) end)
    if not ok or type(src)~="string" then
        error("FunCombat v2 download failed at part "..i..": "..tostring(src))
    end
    parts[#parts+1]=src
end
local source=table.concat(parts)
local fn,err=loadstring(source,"FunCombatNativeRuntimeV2")
if not fn then
    error("FunCombat v2 compile failed: "..tostring(err))
end
return fn()
