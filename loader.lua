-- FunCombat / Null Protocol stable client entrypoint v2.2
-- Native RBXM base + original presentation polish from the source place.
local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/runtime/"
local parts={}
for i=1,7 do
    local url=BASE.."v2_part"..i..".lua?cb="..tostring(os.clock()).."_"..i
    local ok,src=pcall(function() return game:HttpGet(url) end)
    if not ok or type(src)~="string" then
        error("FunCombat v2.2 download failed at part "..i..": "..tostring(src))
    end
    -- StarterPlayer is left un-packed at runtime because Xeno's pure-Lua LZ4
    -- wrapper can stall on it. The base loads its first root; v2.2 supplies the
    -- original presentation behavior that matters on the live character.
    if i==2 then
        src=src:gsub('%["StarterPlayer%.rbxm"%]%s*=%s*true,%s*','')
    end
    parts[#parts+1]=src
end
local source=table.concat(parts)
local fn,err=loadstring(source,"FunCombatNativeRuntimeV22Base")
if not fn then error("FunCombat v2.2 base compile failed: "..tostring(err)) end
local okBase,baseErr=pcall(fn)
if not okBase then error("FunCombat v2.2 base runtime failed: "..tostring(baseErr)) end

local okPatch,patchSrc=pcall(function()
    return game:HttpGet(BASE.."v22_polish.lua?cb="..tostring(os.clock()))
end)
if not okPatch or type(patchSrc)~="string" then
    error("FunCombat v2.2 polish download failed: "..tostring(patchSrc))
end
-- Defensive compatibility for the Highlight property name.
patchSrc=patchSrc:gsub("OutlineColor3","OutlineColor")
local patchFn,patchErr=loadstring(patchSrc,"FunCombatOriginalPresentationV22")
if not patchFn then error("FunCombat v2.2 polish compile failed: "..tostring(patchErr)) end
local okRun,runErr=pcall(patchFn)
if not okRun then error("FunCombat v2.2 polish runtime failed: "..tostring(runErr)) end
return true
