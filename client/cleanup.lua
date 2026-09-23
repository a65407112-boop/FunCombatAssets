return function(ctx)
    local Maid = {}
    Maid.__index = Maid
    local function dispose(item)
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then item:Disconnect()
        elseif kind == "Instance" then item:Destroy()
        elseif type(item) == "function" then item()
        elseif type(item) == "table" then
            if item.destroy then item:destroy() elseif item.Destroy then item:Destroy() end
        end
    end
    function Maid.new(parent)
        local self = setmetatable({items = {}, parent = parent, dead = false}, Maid)
        if parent then parent:add(self) end
        return self
    end
    function Maid:add(item)
        if item == nil then return item end
        if self.dead then pcall(dispose, item) else self.items[item] = true end
        return item
    end
    function Maid:remove(item, shouldDispose)
        if self.items[item] then
            self.items[item] = nil
            if shouldDispose then pcall(dispose, item) end
        end
    end
    function Maid:scope() return Maid.new(self) end
    function Maid:destroy()
        if self.dead then return end
        self.dead = true
        if self.parent then self.parent:remove(self); self.parent = nil end
        local items = self.items
        self.items = {}
        for item in pairs(items) do
            local ok, err = pcall(dispose, item)
            if not ok and ctx.report then ctx.report("Cleanup: " .. tostring(err)) end
        end
    end
    return Maid.new()
end
