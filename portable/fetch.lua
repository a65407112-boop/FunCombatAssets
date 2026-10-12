local F={};F.__index=F
function F.adler(body)
    local a,b=1,0
    for i=1,#body do a=(a+body:byte(i))%65521;b=(b+a)%65521 end
    return b*65536+a
end
function F.new(options)return setmetatable({options=options},F)end
function F:get(url,metadata)
    local o=self.options
    assert(not o.cancelled(),"Fetch cancelled: "..url)
    local done,body,failure,expired=false,nil,nil,false
    o.spawn(function()
        local ok,result=pcall(o.request,url)
        if expired or o.cancelled() then return end
        if ok then body=result else failure=result end
        done=true
    end)
    local deadline=o.clock()+o.timeout
    while not done and not o.cancelled() and o.clock()<deadline do o.wait(0.05)end
    expired=not done
    assert(not o.cancelled(),"Fetch cancelled: "..url)
    assert(done,"HTTP timeout after "..o.timeout.."s: "..url)
    assert(not failure,"HTTP failed: "..url..": "..tostring(failure))
    assert(type(body)=="string" and #body>0,"HTTP returned an empty/non-text body: "..url)
    if metadata then
        assert(#body==metadata.bytes,"Resource length mismatch: "..url)
        assert(F.adler(body)==metadata.adler32,"Resource checksum mismatch: "..url)
        if o.hash and metadata.sha256 then
            local ok,hash=pcall(o.hash,body,"sha256")
            if ok and type(hash)=="string" and #hash==64 then assert(hash:lower()==metadata.sha256,"Resource SHA-256 mismatch: "..url)end
        end
    end
    return body
end
return F
