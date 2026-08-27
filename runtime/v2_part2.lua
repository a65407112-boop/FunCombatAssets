local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/client/"
local CACHE="FunCombatClientV2"
local MULTI={ ["StarterGui.rbxm"]=true, ["StarterPlayer.rbxm"]=true, ["Lighting.rbxm"]=true, ["Billboards.rbxm"]=true }
local MAGIC="<roblox!"..string.char(0x89,0xff,0x0d,0x0a,0x1a,0x0a)

if type(writefile)~="function" then error("executor needs writefile() for native RBXM") end
pcall(function()
    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder(CACHE)) then makefolder(CACHE) end
end)

local function u32(s,p)
    local a,b,c,d=string.byte(s,p,p+3)
    if not d then error("RBXM truncated while reading u32") end
    return a+b*256+c*65536+d*16777216
end
local function p32(n)
    n=n%4294967296
    local a=n%256;n=math.floor(n/256)
    local b=n%256;n=math.floor(n/256)
    local c=n%256;n=math.floor(n/256)
    local d=n%256
    return string.char(a,b,c,d)
end
local function writeString(s) return p32(#s)..s end
local function packChunk(name,raw) return name..p32(0)..p32(#raw)..p32(0)..raw end

local function bytesToString(bytes)
    local parts={}
    for i=1,#bytes,7000 do
        local t={}
        local last=math.min(i+6999,#bytes)
        for j=i,last do t[#t+1]=bytes[j] end
        parts[#parts+1]=string.char(unpackf(t))
    end
    return table.concat(parts)
end
local function lz4Decompress(src,expected)
    local i=1;local out={}
    while i<=#src do
        local token=string.byte(src,i);i=i+1
        local lit=math.floor(token/16)
        if lit==15 then
            while true do
                local x=string.byte(src,i);if not x then error("bad LZ4 literal length") end;i=i+1;lit=lit+x
                if x~=255 then break end
            end
        end
        for j=0,lit-1 do
            local b=string.byte(src,i+j);if not b then error("bad LZ4 literal") end
            out[#out+1]=b
        end
        i=i+lit
        if i>#src then break end
        local lo,hi=string.byte(src,i,i+1);if not hi then error("bad LZ4 offset") end;i=i+2
        local off=lo+hi*256
        if off<=0 or off>#out then error("bad LZ4 back-reference") end
        local m=token%16
        if m==15 then
            while true do
                local x=string.byte(src,i);if not x then error("bad LZ4 match length") end;i=i+1;m=m+x
                if x~=255 then break end
            end
        end
        m=m+4
        for _=1,m do out[#out+1]=out[#out-off+1] end
    end
    if expected and #out~=expected then error("LZ4 size mismatch "..#out.."/"..expected) end
    return bytesToString(out)
end
local function decodeRefs(s,n)
    local vals={};local acc=0
    for i=1,n do
        local b1=string.byte(s,i) or 0
        local b2=string.byte(s,i+n) or 0
        local b3=string.byte(s,i+2*n) or 0
        local b4=string.byte(s,i+3*n) or 0
        local u=b1*16777216+b2*65536+b3*256+b4
        local d
        if u%2==0 then d=math.floor(u/2) else d=-(math.floor(u/2)+1) end
        acc=acc+d;vals[i]=acc
    end
    return vals
end
local function encodeRefs(vals)
    local cols={{},{},{},{}}
    local prev=0
    for _,v in ipairs(vals) do
        local d=v-prev;prev=v
        local u=d>=0 and d*2 or (-d*2-1)
        local b4=u%256;u=math.floor(u/256)
        local b3=u%256;u=math.floor(u/256)
        local b2=u%256;u=math.floor(u/256)
        local b1=u%256
        cols[1][#cols[1]+1]=b1;cols[2][#cols[2]+1]=b2;cols[3][#cols[3]+1]=b3;cols[4][#cols[4]+1]=b4
    end
    local out={}
    for c=1,4 do for _,b in ipairs(cols[c]) do out[#out+1]=b end end
    return bytesToString(out)
end
local function wrapMultiRoot(data)
    if data:sub(1,14)~=MAGIC then error("not a Roblox binary model") end
    local classCount=u32(data,17)
    local instanceCount=u32(data,21)
    local wrapperRef=instanceCount
    local wrapperCid=classCount
    local out={data:sub(1,16),p32(classCount+1),p32(instanceCount+1),data:sub(25,32)}
    local pos=33;local inserted=false;local foundPrnt=false
    while pos+15<=#data do
        local name=data:sub(pos,pos+3)
        local cl=u32(data,pos+4);local dl=u32(data,pos+8)
        local len=(cl~=0) and cl or dl
        local bodyStart=pos+16;local bodyEnd=bodyStart+len-1
        if bodyEnd>#data then error("RBXM chunk overrun: "..name) end
        local body=data:sub(bodyStart,bodyEnd)
        if name=="PRNT" then
            foundPrnt=true
            if not inserted then
                local inst=p32(wrapperCid)..writeString("Folder")..string.char(0)..p32(1)..encodeRefs({wrapperRef})
                local prop=p32(wrapperCid)..writeString("Name")..string.char(1)..writeString("__FunCombatPack")
                out[#out+1]=packChunk("INST",inst)
                out[#out+1]=packChunk("PROP",prop)
                inserted=true
            end
            local raw=(cl~=0) and lz4Decompress(body,dl) or body
            local ver=string.byte(raw,1) or 0
            local n=u32(raw,2)
            local rp=6
            local kids=decodeRefs(raw:sub(rp,rp+4*n-1),n);rp=rp+4*n
            local pars=decodeRefs(raw:sub(rp,rp+4*n-1),n)
            for i=1,#pars do if pars[i]==-1 then pars[i]=wrapperRef end end
            kids[#kids+1]=wrapperRef;pars[#pars+1]=-1
            local nr=string.char(ver)..p32(n+1)..encodeRefs(kids)..encodeRefs(pars)
            out[#out+1]=packChunk("PRNT",nr)
        else
            out[#out+1]=data:sub(pos,bodyEnd)
        end
        pos=bodyEnd+1
        if name=="END\0" then break end
    end
