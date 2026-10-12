-- Track real character parts even before their visual proxy is ready.
local C={};C.__index=C
function C.new(factory)return setmetatable({factory=factory,sources={},groups={}},C)end
function C:add(group,source)
    if group.seen[source] or not source.Parent then return end;group.seen[source]=true
    for _,body in ipairs(group.bodies)do if body.Parent then group.scope:add(self.factory(body,source))end end
end
function C:track(source)
    if self.sources[source] then return end;self.sources[source]=true
    for _,group in pairs(self.groups)do self:add(group,source)end
end
function C:untrack(source)self.sources[source]=nil end
function C:start(key,bodies,scope)
    local g={bodies=bodies,scope=scope,seen={}};self.groups[key]=g
    for source in pairs(self.sources)do self:add(g,source)end
    return g
end
function C:stop(key)self.groups[key]=nil end
return C
