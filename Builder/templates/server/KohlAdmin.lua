-- Run the original Kohl's Admin Infinite loader against its genuine native
-- Credit Script and configuration. All commands/UI come from the verified
-- upstream dependency, not a replacement implementation.
local K={}
local Handle={};Handle.__index=Handle
local MODULE_ID=1868400649
local LOADER_NAME="Kohl's Admin Infinite"
local BRIDGE_NAME="FunCombatDummy"
function Handle:status() return {state=self.state,error=self.error,assetId=MODULE_ID} end
function Handle:complete(state,why)
    if self.state~="pending" then return end
    self.state,self.error=state,why
    if self.credit then
        self.credit:SetAttribute("FunCombatKohlState",state)
        self.credit:SetAttribute("FunCombatKohlError",why or "")
    end
    if why then warn("FunCombat Kohl's Admin: "..why) end
    if self.onChanged then
        local ok,failure=pcall(self.onChanged,self:status())
        if not ok then warn("FunCombat Kohl status callback: "..tostring(failure)) end
    end
end
local function validUserId(value)
    return value==nil or (type(value)=="number" and value==value and value>=1 and value<=1e11 and value%1==0)
end
function K.commands(bridge)
    assert(typeof(bridge)=="Instance" and bridge:IsA("BindableFunction"),"FunCombat dummy bridge is missing.")
    return {
        {{"dummy","spawndummy"},{"Spawn an original game combat dummy, optionally using an avatar user ID.","[userId]"},6,{"number/"},
            function(player,args)
                local accepted,why=bridge:Invoke(player,args[1])
                if not accepted then error(why or "The original game dummy request was rejected.") end
            end},
    }
end
function K.start(credit,access,world,timeoutSeconds,onChanged)
    local handle=setmetatable({state="pending",onChanged=onChanged},Handle)
    if typeof(credit)~="Instance" or not credit:IsA("Script") then
        handle:complete("error","The original Kohl's Admin Credit Script is missing.");return handle
    end
    handle.credit=credit
    credit.Disabled=true
    local settings=credit:FindFirstChild("Settings")
    local custom=credit:FindFirstChild("Custom Commands") or credit:FindFirstChild("Custom_Commands")
    if not settings or not settings:IsA("ModuleScript") or not custom or not custom:IsA("ModuleScript") then
        handle:complete("error","The original Kohl's Admin Credit Script requires child ModuleScripts Settings and Custom Commands.")
        return handle
    end
    local service=game:GetService("ServerScriptService")
    local existing=service:FindFirstChild(LOADER_NAME)
    if (existing and existing~=credit) or _G.KAU then
        handle:complete("error","Kohl's Admin Infinite is already loading; refusing a duplicate hosted dependency.");return handle
    end
    if type(access)~="table" or type(access.allowed)~="function" then
        handle:complete("error","Published creator access is missing for the Kohl dummy command.");return handle
    end
    credit.Name=LOADER_NAME;credit.Parent=service
    local previous=credit:FindFirstChild(BRIDGE_NAME)
    if previous then previous:Destroy() end
    local bridge=Instance.new("BindableFunction");bridge.Name=BRIDGE_NAME;bridge.Parent=credit
    bridge.OnInvoke=function(player,userId)
        if not access:allowed(player) then return false,"Only the published game creator can spawn an admin dummy." end
        if not validUserId(userId) then return false,"Dummy avatar user ID must be a positive integer no greater than 100000000000." end
        if not world or type(world.dummy)~="function" then return false,"The original game dummy spawner is unavailable." end
        local ok,accepted,why=pcall(world.dummy,world,player,userId)
        if not ok then return false,"Original dummy spawner failed: "..tostring(accepted) end
        return accepted==true,why
    end
    credit:SetAttribute("FunCombatKohlAssetId",MODULE_ID)
    credit:SetAttribute("FunCombatKohlState","pending")
    credit:SetAttribute("FunCombatKohlError","")
    -- Reserve the original legacy selector synchronously before task.spawn.
    _G.KAU=true
    local timeout=type(timeoutSeconds)=="number" and timeoutSeconds or 20
    if timeout~=timeout or timeout<=0 or timeout>60 then timeout=20 end
    task.delay(timeout,function()
        handle:complete("timeout","Kohl's Admin dependency "..MODULE_ID.." timed out after "..timeout.." seconds.")
    end)
    task.spawn(function()
        -- These are the original source Credit Script's startup operations.
        local ok,result=pcall(require,MODULE_ID)
        if not ok then
            handle:complete("error","Kohl's Admin dependency "..MODULE_ID.." failed to load: "..tostring(result))
        elseif result~=true then
            handle:complete("error","Kohl's Admin dependency "..MODULE_ID.." did not return the original legacy startup result.")
        else
            handle:complete("ready")
        end
    end)
    return handle
end
return K
