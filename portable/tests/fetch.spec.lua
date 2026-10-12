local ok,F=pcall(dofile,"portable/fetch.lua")
assert(ok,"Bounded portable fetch module must exist")
assert(F.adler("abc")==38600999)
local clock=0
local f=F.new({timeout=0.2,clock=function()return clock end,wait=function(dt)clock=clock+dt end,
    spawn=function(fn)fn()end,request=function()return "abc"end,cancelled=function()return false end})
assert(f:get("test://asset",{bytes=3,adler32=38600999})=="abc")
local good,why=pcall(f.get,f,"test://asset",{bytes=4,adler32=38600999});assert(not good and tostring(why):find("length"))
good,why=pcall(f.get,f,"test://asset",{bytes=3,adler32=9});assert(not good and tostring(why):find("checksum"))
local late
clock=0;local stalled=F.new({timeout=0.2,clock=function()return clock end,wait=function(dt)clock=clock+dt end,
    spawn=function(fn)late=fn end,request=function()return "late body"end,cancelled=function()return false end})
good,why=pcall(stalled.get,stalled,"test://stalled");assert(not good and tostring(why):find("timeout"));late()
clock=0;local cancelled=F.new({timeout=9,clock=function()return clock end,wait=function(dt)clock=clock+dt end,
    spawn=function()end,request=function()return "unused"end,cancelled=function()return clock>=0.1 end})
good,why=pcall(cancelled.get,cancelled,"test://cancelled");assert(not good and tostring(why):find("cancelled")and clock<1)
print("FETCH TESTS 6")
