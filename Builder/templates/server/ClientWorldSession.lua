-- World entry is independent of avatar/morph implementation.
local Session={};Session.__index=Session

function Session.start(world,network,buildId,config)
    local Players=game:GetService("Players")
    local Run=game:GetService("RunService")
    local room=assert(workspace:FindFirstChild(config.room),"Waiting room is missing")
    local spawn=assert(room:FindFirstChild(config.spawn),"Waiting room spawn is missing")
    local self=setmetatable({world=world,config=config,buildId=buildId,members={},generations={},nextSession=0,revision=0,map=nil},Session)
    local originalSpawn=world.spawn
    local function clearMotion(root)
        root.Velocity=Vector3.new();root.RotVelocity=Vector3.new()
    end
    function self:toRoom(player,root)
        root=root or player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsDescendantOf(workspace) then
            root.CFrame=spawn.CFrame*CFrame.new(0,4,0);clearMotion(root)
        end
        return true
    end
    function self:isReady(player)
        local member=self.members[player]
        return member~=nil and member.map==world.activeMap and world.activeMap~=nil
            and tick()-member.seen<=config.lease
    end
    function self:refresh()
        local map=world.activeMap
        if map~=self.map then self.map=map;self.revision+=1 end
        for player in pairs(self.members) do
            if not player.Parent or not self:isReady(player) then
                self.members[player]=nil
                if player.Parent then player:SetAttribute(config.readyAttribute,false);self:toRoom(player) end
            end
        end
    end
    function self:state(player,accepted,why)
        local key=self.map and config.maps[self.map.Name]
        return {buildId=buildId,available=key~=nil,mapKey=key,mapAlias=self.map and self.map.Name,
            revision=self.revision,session=self.generations[player],joined=self:isReady(player),accepted=accepted==true,error=why}
    end
    function world:spawn(record,index)
        self.clientWorldSession:refresh()
        local player=record.player or record.root and Players:GetPlayerFromCharacter(record.root.Parent)
        if player and not self.clientWorldSession:isReady(player) then
            return self.clientWorldSession:toRoom(player,record.root)
        end
        return originalSpawn(self,record,index)
    end
    world.clientWorldSession=self
    self:refresh()
    local remote=Instance.new("RemoteFunction");remote.Name=config.remote;remote.Parent=network
    remote.OnServerInvoke=function(player,data)
        self:refresh()
        if type(data)~="table" or data.buildId~=buildId then return self:state(player,false,"World build mismatch") end
        if data.op=="open" then
            self.members[player]=nil;player:SetAttribute(config.readyAttribute,false);self:toRoom(player)
            self.nextSession+=1;self.generations[player]=self.nextSession
            return self:state(player,true)
        end
        if not self.generations[player] or data.session~=self.generations[player] then
            return self:state(player,false,"World loader session was replaced or closed")
        end
        if data.op=="leave" then
            self.members[player]=nil;self.generations[player]=nil
            player:SetAttribute(config.readyAttribute,false);self:toRoom(player)
            return self:state(player,true)
        elseif data.op=="status" then
            if self.members[player] then self.members[player].seen=tick() end
            return self:state(player,true)
        elseif data.op~="join" then return self:state(player,false,"Unknown world operation") end
        local key=self.map and config.maps[self.map.Name]
        if not key or data.revision~=self.revision or data.mapKey~=key then
            return self:state(player,false,"World changed while loading")
        end
        if not self:isReady(player) then
            self.members[player]={map=self.map,seen=tick()}
            local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsDescendantOf(workspace) then
                local ok,why=originalSpawn(world,{root=root,player=player})
                if not ok then self.members[player]=nil;self:toRoom(player);return self:state(player,false,why) end
            end
        else self.members[player].seen=tick() end
        player:SetAttribute(config.readyAttribute,true)
        return self:state(player,true)
    end
    local function bindPlayer(player)
        player.RespawnLocation=spawn
        player:SetAttribute(config.readyAttribute,false)
        local function characterAdded(character)
            coroutine.wrap(function()
                local deadline=tick()+10
                local root
                repeat
                    if not player.Parent or player.Character~=character then return end
                    root=character:FindFirstChild("HumanoidRootPart")
                    if root and root:IsDescendantOf(workspace) then break end
                    wait(0.05)
                until tick()>=deadline
                if root and player.Character==character and not self:isReady(player) then self:toRoom(player,root) end
            end)()
        end
        player.CharacterAdded:Connect(characterAdded)
        if player.Character then characterAdded(player.Character) end
    end
    Players.PlayerAdded:Connect(bindPlayer)
    Players.PlayerRemoving:Connect(function(player) self.members[player]=nil;self.generations[player]=nil end)
    for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
    Run.Heartbeat:Connect(function() self:refresh() end)
    return self
end

return Session
