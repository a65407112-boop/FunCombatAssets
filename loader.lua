-- The generated build is preconfigured for the project's public runtime repository.
-- FUNCOMBAT_RUNTIME_BASE can still override it and must end with a slash.
local environment = (getgenv and getgenv()) or _G
local base = environment.FUNCOMBAT_RUNTIME_BASE
	or "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/"
local localRoot = environment.FUNCOMBAT_RUNTIME_LOCAL_ROOT
local cacheTag = tostring(environment.FUNCOMBAT_RUNTIME_CACHE_TAG or "fc-ui-20260829-06")
local cache = {}

local function read(path)
	if localRoot then
		assert(readfile, "readfile is required for local runtime mode")
		return readfile(localRoot .. "/" .. path)
	end
	return game:HttpGet(base .. path .. "?v=" .. cacheTag, true)
end

local function module(path)
	if cache[path] ~= nil then return cache[path] end
	local source = read(path)
	local chunk, problem = loadstring(source, "@FunCombat_Runtime/" .. path)
	assert(chunk, problem)
	local value = chunk()
	cache[path] = value
	return value
end

local protocol = module("protocol.lua")
local names = module("names.lua")
local core = module("core.lua")
local runToken = game:GetService("HttpService"):GenerateGUID(false)
environment.FUNCOMBAT_RUNTIME_RUN = runToken
return core.start({
	module = module,
	protocol = protocol,
	names = names,
	base = base,
	environment = environment,
	run_token = runToken,
})
