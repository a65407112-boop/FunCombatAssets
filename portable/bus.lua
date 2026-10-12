-- Presentation callbacks in this Lua VM only. No remotes or server transport.
local Bus={};Bus.__index=Bus
function Bus.new(clock,report) return setmetatable({clock=clock,report=report,listeners={},dead=false},Bus) end
function Bus:now() return self.clock() end
function Bus:on(kind,fn)
    local connection={};local owner=self
    self.listeners[kind]=self.listeners[kind] or {}
    if not self.dead then self.listeners[kind][connection]=fn end
    function connection:Disconnect() if owner.listeners[kind] then owner.listeners[kind][self]=nil end end
    connection.destroy=connection.Disconnect
    return connection
end
function Bus:emit(kind,data)
    if self.dead then return end
    local snapshot={}
    for token,fn in pairs(self.listeners[kind] or {}) do snapshot[#snapshot+1]={token,fn} end
    for _,entry in ipairs(snapshot) do
        if self.listeners[kind] and self.listeners[kind][entry[1]] then
            local ok,err=pcall(entry[2],data)
            if not ok and self.report then self.report("Local "..kind.." listener: "..tostring(err)) end
        end
    end
end
function Bus:destroy() self.dead=true;self.listeners={} end
return Bus
