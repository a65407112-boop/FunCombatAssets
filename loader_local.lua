local environment = (getgenv and getgenv()) or _G
environment.FUNCOMBAT_RUNTIME_LOCAL_ROOT = environment.FUNCOMBAT_RUNTIME_LOCAL_ROOT
	or "FunCombat_Runtime"
return assert(loadstring(readfile(environment.FUNCOMBAT_RUNTIME_LOCAL_ROOT .. "/loader.lua"),
	"@FunCombat_Runtime/loader.lua"))()
