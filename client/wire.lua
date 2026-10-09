return function(ctx)
    local encode,decode,maps={},{},{}
    for name,id in pairs(ctx.protocol.presentationIds or {}) do encode[name]=id;decode[id]=name end
    for name,id in pairs(ctx.identifiers.mapNames or {}) do encode[name]=id;decode[id]=name;maps[id]=name end
    local function transform(value,aliases,seen,depth)
        if type(value)=='string' then
            if aliases[value] then return aliases[value] end
            if aliases==decode then
                for id,name in pairs(maps) do if value:find(id,1,true) then value=value:gsub(id,name) end end
            end
            return value
        end
        if type(value)~='table' or typeof(value)=='Instance' then return value end
        depth=depth or 0;assert(depth<24,'Wire payload nesting limit exceeded')
        seen=seen or {};if seen[value] then return seen[value] end
        local copy={};seen[value]=copy
        for key,item in pairs(value) do copy[type(key)=='string' and (aliases[key] or key) or key]=transform(item,aliases,seen,depth+1) end
        return copy
    end
    return {encode=function(_,value) return transform(value,encode) end,decode=function(_,value) return transform(value,decode) end}
end
