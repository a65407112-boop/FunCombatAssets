-- Pure visual motion: map probes constrain an anchored proxy; no engine forces.
local R={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
function R.new(position,velocity)
    local v=velocity or {}
    return {position={x=position.x,y=position.y,z=position.z},velocity={x=clamp(v.x or 0,-40,40),y=clamp(v.y or 2,-50,50),z=clamp(v.z or 0,-40,40)},age=0,grounded=false}
end
function R.contact(old,proposed,cast)
    local delta={x=proposed.x-old.x,y=proposed.y-old.y,z=proposed.z-old.z}
    if delta.x*delta.x+delta.y*delta.y+delta.z*delta.z>0.0001 then
        local hit,normal,supported=cast(old,delta)
        if not supported then return old end
        if hit then
            normal=normal or {x=0,y=1,z=0}
            return {x=hit.x+normal.x*0.65,y=hit.y+normal.y*0.65,z=hit.z+normal.z*0.65}
        end
    end
    local ground,_,supported=cast({x=proposed.x,y=proposed.y+1,z=proposed.z},{x=0,y=-1.65,z=0})
    if not supported then return old end
    if ground and proposed.y<=ground.y+0.65 then return {x=proposed.x,y=ground.y+0.65,z=proposed.z}end
end
function R.step(s,dt,gravity,probe)
    if not finite(dt)or dt<=0 then return s end
    dt=math.min(dt,1/30);gravity=finite(gravity)and clamp(gravity,0,500)or 196.2
    local old=s.position;local v=s.velocity;v.y=v.y-gravity*dt
    local proposed={x=old.x+v.x*dt,y=old.y+v.y*dt,z=old.z+v.z*dt}
    local contact=probe(old,proposed)
    s.grounded=contact~=nil
    if contact then
        proposed=contact;v.y=0
        local damping=math.exp(-9*dt);v.x=v.x*damping;v.z=v.z*damping
    end
    s.position=proposed;s.age=s.age+dt;return s
end
return R
