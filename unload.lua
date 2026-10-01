-- Emergency/manual rollback for the external Fun Combat runtime.
-- This only removes client-side changes made by loader.lua. It never writes to GitHub.
local environment = (type(getgenv) == "function" and getgenv()) or _G
local slot = "FunCombat_ExternalRuntime"
local runtime = environment[slot]

if type(runtime) ~= "table" then
    warn("[Fun Combat] No active external runtime was found.")
    return false
end

runtime.cancelled = true
local ok, failure = pcall(function()
    if type(runtime.destroy) == "function" then
        runtime:destroy()
    elseif runtime.cleanup and type(runtime.cleanup.destroy) == "function" then
        runtime.cleanup:destroy()
    end
end)

if environment[slot] == runtime then
    environment[slot] = nil
end

if not ok then
    warn("[Fun Combat] Rollback completed with a cleanup error: " .. tostring(failure))
    return false
end

print("[Fun Combat] External runtime unloaded and registered client-side changes were cleaned up.")
return true
