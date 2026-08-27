-- FunCombat / Null Protocol stable client entrypoint v2.3
-- Native RBXM base + source-place presentation + literal original Info/Music assets.
local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/runtime/"
local parts={}
for i=1,7 do
    local url=BASE.."v2_part"..i..".lua?cb="..tostring(os.clock()).."_"..i
    local ok,src=pcall(function() return game:HttpGet(url) end)
    if not ok or type(src)~="string" then
        error("FunCombat v2.3 download failed at part "..i..": "..tostring(src))
    end
    if i==2 then
        src=src:gsub('%["StarterPlayer%.rbxm"%]%s*=%s*true,%s*','')
    end
    parts[#parts+1]=src
end
local source=table.concat(parts)
local fn,err=loadstring(source,"FunCombatNativeRuntimeV23Base")
if not fn then error("FunCombat v2.3 base compile failed: "..tostring(err)) end
local okBase,baseErr=pcall(fn)
if not okBase then error("FunCombat v2.3 base runtime failed: "..tostring(baseErr)) end

local okPatch,patchSrc=pcall(function()
    return game:HttpGet(BASE.."v22_polish.lua?cb="..tostring(os.clock()))
end)
if not okPatch or type(patchSrc)~="string" then error("FunCombat v2.3 polish download failed: "..tostring(patchSrc)) end
patchSrc=patchSrc:gsub("OutlineColor3","OutlineColor")
patchSrc=patchSrc:gsub("currentSound%.Volume=%.5","currentSound.Volume=.2")
-- Base v2 already owns the server-safe weapon controller. Do not wire a second
-- Activated/Equipped stack from the older polish layer.
patchSrc=patchSrc:gsub('%-%- ORIGINAL WEAPON PRESENTATION.-setStatus%(%"READY v2%.2.-%"%)','setStatus("READY v2.2 | original info + music + emotes + leaning")')
local patchFn,patchErr=loadstring(patchSrc,"FunCombatOriginalPresentationV22")
if not patchFn then error("FunCombat v2.3 polish compile failed: "..tostring(patchErr)) end
local okRun,runErr=pcall(patchFn)
if not okRun then error("FunCombat v2.3 polish runtime failed: "..tostring(runErr)) end

local okExact,exactSrc=pcall(function()
    return game:HttpGet(BASE.."v23_exact_assets.lua?cb="..tostring(os.clock()))
end)
if not okExact or type(exactSrc)~="string" then error("FunCombat v2.3 exact-assets download failed: "..tostring(exactSrc)) end
local exactFn,exactErr=loadstring(exactSrc,"FunCombatExactAssetsV23")
if not exactFn then error("FunCombat v2.3 exact-assets compile failed: "..tostring(exactErr)) end
local okExactRun,exactRunErr=pcall(exactFn)
if not okExactRun then error("FunCombat v2.3 exact-assets runtime failed: "..tostring(exactRunErr)) end
return true
