-- Original 5s intermission, 15s vote, 5s switch notice, 101*12s round.
local Players=game:GetService("Players")
local V={};V.__index=V
local function now() return tick() end
function V.new(combat,world,maps)
    local self=setmetatable({combat=combat,world=world,maps=maps,phase="waiting",deadline=now()+5,revision=0,votes={},candidates={},active=false},V)
    combat.voting=self
    return self
end
function V:state()
    local counts={}
    for _,candidate in ipairs(self.candidates) do counts[candidate.name]=0 end
    for player,map in pairs(self.votes) do if player.Parent and counts[map] then counts[map]=counts[map]+1 end end
    return {active=self.active,candidates=self.candidates,votes=counts,remaining=math.max(0,self.deadline-now()),revision=self.revision}
end
function V:publish() self.revision=self.revision+1;self.combat:emit("Voting",self:state()) end
function V:vote(player,name)
    if not self.active or now()>self.deadline then return end
    for _,candidate in ipairs(self.candidates) do
        if candidate.name==name then if self.votes[player]~=name then self.votes[player]=name;self:publish() end;return end
    end
end
function V:remove(player) if self.votes[player] then self.votes[player]=nil;self:publish() end end
function V:begin()
    local maps=self.maps:GetChildren()
    table.sort(maps,function(a,b) return a.Name<b.Name end)
    while #maps>3 do table.remove(maps,math.random(1,#maps)) end
    self.candidates={};self.votes={}
    for _,map in ipairs(maps) do self.candidates[#self.candidates+1]={name=map.Name} end
    if #self.candidates==0 then error("Original map templates are missing") end
    self.active=true;self.phase="vote";self.deadline=now()+15;self:publish()
end
function V:winner()
    local counts=self:state().votes;local winner=self.candidates[1].name
    for _,candidate in ipairs(self.candidates) do if counts[candidate.name]>counts[winner] then winner=candidate.name end end
    return winner
end
function V:load(name)
    local template=self.maps:FindFirstChild(name)
    if not template then error("Unallowlisted map") end
    self.combat.preserveStreak={}
    for _,player in ipairs(Players:GetPlayers()) do
        local r=self.combat.players[player]
        if r then
            self.combat.preserveStreak[player]=player.leaderstats.Killstreak.Value
            if r.interaction then self.combat:release(r.interaction) end
            if r.carrying then self.combat:drop(r) end
        end
    end
    for character in pairs(self.combat.dummyOwners) do self.combat:remove(character);character:Destroy() end
    for _,object in ipairs(workspace:GetChildren()) do if object:FindFirstChild("IsMap") then object:Destroy() end end
    local map=template:Clone();map.Parent=workspace;self.world.activeMap=map
    for index,player in ipairs(Players:GetPlayers()) do
        local r=self.combat.players[player]
        if r then self.world:spawn(r,index) end
        if not self.combat.noRespawn[player] then
            coroutine.wrap(function()
                local ok,err=pcall(function() player:LoadCharacter() end)
                if not ok then warn("Map respawn: "..tostring(err)) end
            end)()
        end
    end
    self.world:chooseWeather()
end
function V:step()
    local count=#Players:GetPlayers()
    if self.phase=="round" and count<2 then self.phase="waiting";self.deadline=now()+5 end
    if now()<self.deadline then return end
    if self.phase=="waiting" then
        if count>=2 then self:begin() else self.deadline=now()+5 end
    elseif self.phase=="vote" then
        self.active=false;self.selected=self:winner();self:publish()
        if not self.world.activeMap or self.world.activeMap.Name~=self.selected then
            self.world:notice("Switching to Map: "..self.selected.." In 5 Seconds","map")
            self.phase="switch";self.deadline=now()+5
        else self.phase="round";self.deadline=now()+1212 end
    elseif self.phase=="switch" then self:load(self.selected);self.phase="round";self.deadline=now()+1212
    elseif self.phase=="round" then self.phase="waiting";self.deadline=now()+5 end
end
function V:start()
    coroutine.wrap(function() while self.maps.Parent do wait(0.25);self:step() end end)()
end
return V
