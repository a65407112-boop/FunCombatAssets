-- Virtual combat state. Keys may be source Instances, but no Roblox API is used.
local Core = {}; Core.__index = Core
local function finite(x) return type(x)=="number" and x==x and math.abs(x)<math.huge end
function Core.new(config)
    return setmetatable({config=config,records={},listeners={},generation=0,serial=0},Core)
end
function Core:onChanged(fn)
    local token={};self.listeners[token]=fn
    local owner=self
    function token:Disconnect() owner.listeners[self]=nil end
    token.destroy=token.Disconnect
    return token
end
function Core:changed(r,reason)
    for _,fn in pairs(self.listeners) do fn(r,reason) end
end
function Core:valid(r) return r and r.alive and self.records[r.key]==r end
function Core:free(r) return self:valid(r) and not r.downed and not r.ragdolled and not r.busy and not r.carrying and not r.carriedBy end
function Core:register(key)
    assert(key~=nil,"Missing local character key")
    if self.records[key] then return self.records[key] end
    self.generation=self.generation+1
    local r={key=key,alive=true,generation=self.generation,health=100,downed=false,ragdolled=false,
        busy=false,weapon="",combo=1,nextSwing=0,lastSwing=-100,hits=0,kills=0,revision=0}
    self.records[key]=r;self:changed(r,"register");return r
end
function Core:swing(a,now)
    if not finite(now) or not self:free(a) or now<a.nextSwing then return nil,"Character is busy or the swing is cooling down" end
    if now-a.lastSwing>1.5 then a.combo=1 end
    local combo=a.combo;a.combo=combo%3+1;a.lastSwing=now
    a.nextSwing=now+self.config.SwingCooldown[combo]
    self.serial=self.serial+1
    local attack={id=self.serial,owner=a,combo=combo,damage=self.config.Damage[combo],startup=self.config.Startup[combo],
        start=now,ends=now+self.config.Startup[combo]+self.config.ActiveWindow,hit={}}
    a.attack=attack;self:changed(a,"swing");return attack
end
function Core:hit(a,v,attack,now)
    if not finite(now) or not self:free(a) or not self:valid(v) or a==v or not attack or a.attack~=attack or attack.owner~=a
        or attack.hit[v] or now<attack.start+attack.startup or now>attack.ends or v.busy or v.carriedBy or v.virtualDead then return false end
    attack.hit[v]=true;a.hits=a.hits+1;v.health=math.max(0,v.health-attack.damage)
    v.downed=v.downed or v.health==0 or attack.combo==3
    v.ragdolled=true;v.recoverAt=now+(v.downed and self.config.DownDuration or 0.5)
    self:changed(v,"hit");self:changed(a,"hitCount");return true
end
function Core:canCarry(a,v,distance)
    return self:free(a) and self:valid(v) and a~=v and (v.downed or v.ragdolled) and not v.busy and not v.carriedBy and not v.virtualDead
        and finite(distance) and distance>=0 and distance<=self.config.InteractDistance
end
function Core:carry(a,v,now,distance)
    if not finite(now) or not self:canCarry(a,v,distance) then return false,"Carry needs a nearby downed target and a free character" end
    a.attack=nil;a.carrying=v;v.carriedBy=a;v.downed=true;v.ragdolled=false;v.recoverAt=nil
    self:changed(a,"carry");self:changed(v,"carried");return true
end
function Core:drop(a,now)
    local v=a and a.carrying
    if not v then return false,"You are not carrying a local target" end
    a.carrying=nil
    if v.carriedBy==a then v.carriedBy=nil end
    if self:valid(v) then v.downed=true;v.ragdolled=true;v.recoverAt=now+self.config.DownDuration;self:changed(v,"drop") end
    self:changed(a,"drop");return true
end
function Core:canGlory(a,v,distance)
    local ownsCarry=self:valid(a) and self:valid(v) and a.carrying==v and v.carriedBy==a and not a.busy
    return (self:free(a) or ownsCarry) and self:valid(v) and a~=v and (v.downed or v.ragdolled) and not v.busy and not v.virtualDead
        and (not v.carriedBy or v.carriedBy==a) and finite(distance) and distance>=0 and distance<=self.config.InteractDistance
end
function Core:glory(a,v,now,distance,duration)
    if not finite(now) or not finite(duration) or duration<=0 or duration>30 or not self:canGlory(a,v,distance) then return false,"Glory needs a nearby ragdolled target"end
    if a.carrying then self:drop(a,now)end
    local link={a=a,v=v,finishAt=now+duration}
    a.attack=nil;a.link=link;v.link=link;a.busy=true;v.busy=true;v.ragdolled=false;v.recoverAt=nil
    self:changed(a,"glory");self:changed(v,"gloryTarget");return true
end
function Core:release(link,now,finished)
    if not link or link.released then return end;link.released=true
    local a,v=link.a,link.v
    for _,r in ipairs({a,v})do if r.link==link then r.link=nil;r.busy=false end end
    if self:valid(v)then
        v.ragdolled=true
        if finished then v.health=0;v.virtualDead=true;if self:valid(a)then a.kills=a.kills+1 end end
        v.recoverAt=now+(finished and 3 or self.config.DownDuration);self:changed(v,"gloryEnd")
    end
    if self:valid(a)then self:changed(a,"gloryEnd")end
end
function Core:detach(r,now)
    if not self:valid(r) then return end
    if r.link then self:release(r.link,now,false)end
    if r.carrying then self:drop(r,now) end
    if r.carriedBy then self:drop(r.carriedBy,now) end
    r.alive=false;r.attack=nil;r.weapon="";r.busy=false;self.records[r.key]=nil
    self:changed(r,"remove")
end
function Core:tick(now)
    if not finite(now) then return end
    for _,r in pairs(self.records) do
        if r.link and r.link.a==r and now>=r.link.finishAt then self:release(r.link,now,true)end
        if r.attack and now>r.attack.ends then r.attack=nil end
        if r.recoverAt and now>=r.recoverAt and not r.carriedBy and not r.busy then
            r.recoverAt=nil;r.ragdolled=false
            if r.downed then r.downed=false;r.health=100;r.virtualDead=false end
            self:changed(r,"recover")
        end
    end
end
return Core
