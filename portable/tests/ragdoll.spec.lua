local ok,R=pcall(dofile,'portable/ragdoll.lua');assert(ok,'Portable ragdoll must have a force-free visual solver')
local s=R.new({x=0,y=4,z=0},{x=15,y=5,z=0})
local probes=0
local function floor(_,proposed)
 probes=probes+1;if proposed.y<0.65 then return {x=proposed.x,y=0.65,z=proposed.z}end
end
for i=1,90 do R.step(s,1/60,196.2,floor)end
assert(s.position.y>=0.65 and probes>0,'Ragdoll must settle using a map probe rather than collidable proxy parts')
assert(math.abs(s.velocity.y)<0.001 and math.abs(s.velocity.x)<1,'Floor contact must damp momentum without adding energy')
local a=R.new({x=0,y=10,z=0},{x=0,y=0,z=0});R.step(a,2,196.2,function()end)
assert(a.position.y>9,'A stalled frame must not teleport the proxy below the map')
local before=a.position.y;R.step(a,0/0,196.2,function()end);assert(a.position.y==before,'Invalid frame delta must be ignored')
assert(type(R.contact)=='function','Grounded ragdoll must sweep walls before accepting a floor contact')
local wall=R.contact({x=0,y=0.65,z=0},{x=1,y=0.65,z=0},function(origin,direction)
 if direction.x>0 then return {x=0.8,y=0.65,z=0},{x=-1,y=0,z=0},true end
 return {x=origin.x,y=0,z=0},{x=0,y=1,z=0},true
end)
assert(wall and wall.x<0.2,'Floor contact must not allow a horizontal impulse to pass through a wall')
local ground=R.contact({x=0,y=0.65,z=0},{x=1,y=0.65,z=0},function(origin,direction)
 if direction.x>0 then return nil,nil,true end
 return {x=origin.x,y=0,z=0},{x=0,y=1,z=0},true
end)
assert(ground.x==1 and ground.y==0.65,'Open floor movement must remain available after the wall sweep')
print('VISUAL RAGDOLL TESTS 6')
