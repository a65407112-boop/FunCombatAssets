-- Null Protocol stable loader hotfix
-- This loads the last full runtime implementation by commit, fixes the one
-- patchCore gsub replacement that Luau interprets as capture syntax, then runs it.

local BASE_COMMIT = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/5129021c5eccb630a12ffeba79742bb393c5e569/"
local src = game:HttpGet(BASE_COMMIT .. "loader.lua?cb=" .. tostring(os.clock()))

local old = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%%200==0 then task.wait() end",
        2
    )]]

local new = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        function()
            return "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%200==0 then task.wait() end"
        end,
        2
    )]]

local p = src:find(old, 1, true)
if not p then
    error("Null Protocol hotfix: chunked-mount patch point not found")
end
src = src:sub(1, p - 1) .. new .. src:sub(p + #old)

local fn, err = loadstring(src, "NullProtocolFixedLoader")
if not fn then
    error("Null Protocol hotfix compile failed: " .. tostring(err))
end

return fn()
