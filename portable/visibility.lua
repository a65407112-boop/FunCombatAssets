-- Own only local presentation properties, remembering later game changes.
local V={};V.__index=V
function V.new()return setmetatable({saved={},dead=false},V)end
function V:set(object,property,value)
    if self.dead then return false end
    local byProperty=self.saved[object] or {};self.saved[object]=byProperty
    if byProperty[property] then return true end
    local ok,original=pcall(function()return object[property]end)
    if not ok then return false end
    local entry={original=original,writing=false};byProperty[property]=entry
    local function apply()
        entry.writing=true;local success=pcall(function()object[property]=value end);entry.writing=false;return success
    end
    if not apply() then byProperty[property]=nil;return false end
    local connected,connection=pcall(function()
        return object:GetPropertyChangedSignal(property):Connect(function()
            if self.dead or entry.writing then return end
            local read,current=pcall(function()return object[property]end)
            if read and current~=value then entry.original=current;apply() end
        end)
    end)
    if connected then entry.connection=connection end
    return true
end
function V:destroy()
    if self.dead then return end;self.dead=true
    for object,properties in pairs(self.saved) do
        for property,entry in pairs(properties) do
            if entry.connection then entry.connection:Disconnect()end
            pcall(function()object[property]=entry.original end)
        end
    end
    self.saved={}
end
return V
