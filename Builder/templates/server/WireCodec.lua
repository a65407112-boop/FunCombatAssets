local C={}
function C.transform(value,aliases,seen,depth,budget)
    if budget then budget.left-=1;assert(budget.left>=0,'Wire action size limit exceeded') end
    if budget and type(value)=='string' then assert(#value<=2048,'Wire action string limit exceeded') end
    if type(value)=='string' then return aliases[value] or value end
    if type(value)~='table' or typeof(value)=='Instance' then return value end
    depth=depth or 0;assert(depth<24,'Wire payload nesting limit exceeded')
    seen=seen or {};if seen[value] then return seen[value] end
    local copy={};seen[value]=copy
    for key,item in pairs(value) do
        copy[type(key)=='string' and (aliases[key] or key) or key]=C.transform(item,aliases,seen,depth+1,budget)
    end
    return copy
end
function C.decodeAction(value,aliases) return C.transform(value,aliases,nil,nil,{left=256}) end
return C
