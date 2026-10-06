-- Native access grants the actual published creator and one explicitly configured user ID.
local A={};A.__index=A
local function userId(value)
    return type(value)=="number" and value==value and value>0 and value<=9007199254740991 and value%1==0
end
function A:status()
    return {state=self.state,creatorType=self.creatorType,publishedCreatorId=self.publishedCreatorId,
        ownerUserId=self.ownerUserId,error=self.error,configuredOwnerUserId=self.configuredOwnerUserId,configError=self.configError}
end
function A:grantSource(player)
    if self.destroyed or typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=self.players then return nil end
    if self.state=="ready" and self.ownerUserId~=nil and player.UserId==self.ownerUserId then return "publishedCreator" end
    if self.configuredOwnerUserId~=nil and player.UserId==self.configuredOwnerUserId then return "configuredOwner" end
    return nil
end
function A:allowed(player)
    return self:grantSource(player)~=nil
end
function A:publish(player)
    if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=self.players then return end
    local allowed=self:allowed(player)
    player:SetAttribute("FunCombatAdminAllowed",allowed)
    player:SetAttribute("FunCombatAdminState",self.state)
    player:SetAttribute("FunCombatAdminError",self.error or "")
    player:SetAttribute("FunCombatCreatorUserId",self.ownerUserId or 0)
    player:SetAttribute("FunCombatConfiguredOwnerUserId",self.configuredOwnerUserId or 0)
    player:SetAttribute("FunCombatAdminSource",self:grantSource(player) or "")
    player:SetAttribute("FunCombatAdminConfigError",self.configError or "")
    if self.onChanged then
        local ok,why=pcall(self.onChanged,player,allowed,self:status())
        if not ok then warn("FunCombat admin access callback failed: "..tostring(why)) end
    end
end
function A:complete(state,owner,why)
    -- An engine group query may complete after the deadline; it cannot grant access.
    if self.destroyed or self.state~="pending" then return end
    self.state,self.ownerUserId,self.error=state,owner,why
    for _,player in ipairs(self.players:GetPlayers()) do self:publish(player) end
    if why then warn("FunCombat creator access: "..why) end
end
function A:start()
    if self.started then return self end
    self.started=true
    local creatorId=game.CreatorId
    self.publishedCreatorId=creatorId
    if not userId(creatorId) then
        self.state="error"
        self.error="Published creator identity is unavailable (CreatorId="..tostring(creatorId)..")."
    elseif game.CreatorType==Enum.CreatorType.User then
        self.creatorType="User";self.state="ready";self.ownerUserId=creatorId
    elseif game.CreatorType==Enum.CreatorType.Group then
        self.creatorType="Group";self.state="pending"
    else
        self.state="error";self.error="Unsupported published creator type: "..tostring(game.CreatorType)
    end
    self.connection=self.players.PlayerAdded:Connect(function(player) self:publish(player) end)
    for _,player in ipairs(self.players:GetPlayers()) do self:publish(player) end
    if self.state=="pending" then
        task.delay(self.timeout,function()
            self:complete("timeout",nil,"Creator group "..creatorId.." owner lookup timed out after "..self.timeout.." seconds.")
        end)
        task.spawn(function()
            local ok,result=pcall(function() return game:GetService("GroupService"):GetGroupInfoAsync(creatorId) end)
            if not ok then
                self:complete("error",nil,"Creator group "..creatorId.." owner lookup failed: "..tostring(result))
                return
            end
            local owner=type(result)=="table" and type(result.Owner)=="table" and result.Owner.Id
            if not userId(owner) then
                self:complete("error",nil,"Creator group "..creatorId.." returned no valid owner user ID.")
                return
            end
            self:complete("ready",owner)
        end)
    elseif self.error then
        warn("FunCombat creator access: "..self.error)
    end
    return self
end
function A.new(onChanged,timeoutSeconds,configuredOwnerId)
    local timeout=type(timeoutSeconds)=="number" and timeoutSeconds or 10
    if timeout~=timeout or timeout<=0 or timeout>30 then timeout=10 end
    local self=setmetatable({players=game:GetService("Players"),state="pending",onChanged=onChanged,timeout=timeout},A)
    if configuredOwnerId~=nil then
        if userId(configuredOwnerId) then
            self.configuredOwnerUserId=configuredOwnerId
        else
            self.configError="Configured owner user ID must be a positive integer no greater than 9007199254740991 (received "..tostring(configuredOwnerId)..")."
            warn("FunCombat configured owner access: "..self.configError)
        end
    end
    return self:start()
end
function A:destroy()
    if self.destroyed then return end
    self.destroyed=true;self.state="stopped";self.ownerUserId=nil
    if self.connection then self.connection:Disconnect() end
    for _,player in ipairs(self.players:GetPlayers()) do self:publish(player) end
end
return A
