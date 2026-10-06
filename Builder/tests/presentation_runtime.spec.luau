-- Only Roblox APIs are doubled. CFrame uses ordinary matrix multiplication so
-- a lost quarter-turn is observable independently of the grip implementation.
local now=100
local function tick() return now end
local function wait(seconds) now += seconds or 0.05 end
local function typeof(value) return type(value)=="table" and value.kind or type(value) end
local function signal()
    local callbacks={}
    return {Connect=function(_,fn)
        callbacks[fn]=true
        return {kind="RBXScriptConnection",Disconnect=function() callbacks[fn]=nil end}
    end,fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end}
end
local cf={};cf.__index=cf
local function frame(...) local a={...};if #a==0 then a={0,0,0} end
    if #a==3 then for _,v in ipairs({1,0,0,0,1,0,0,0,1}) do a[#a+1]=v end end
    return setmetatable(a,cf)
end
function cf.__mul(a,b)
    local c={}
    for i=0,2 do
        c[i+1]=a[i+1]+a[4+i*3]*b[1]+a[5+i*3]*b[2]+a[6+i*3]*b[3]
        for j=0,2 do c[4+i*3+j]=a[4+i*3]*b[4+j]+a[5+i*3]*b[7+j]+a[6+i*3]*b[10+j] end
    end
    return setmetatable(c,cf)
end
function cf:Inverse()
    local r=frame(0,0,0,self[4],self[7],self[10],self[5],self[8],self[11],self[6],self[9],self[12])
    for i=0,2 do r[i+1]=-(r[4+i*3]*self[1]+r[5+i*3]*self[2]+r[6+i*3]*self[3]) end
    return r
end
function cf:ToObjectSpace(b) return self:Inverse()*b end
function cf:Lerp(b,alpha) local c={};for i=1,12 do c[i]=self[i]+(b[i]-self[i])*alpha end;return setmetatable(c,cf) end
local CFrame={new=frame,Angles=function(x,y,z)
    assert(y==0 and z==0,"Only the X-axis grip rotation is used in these fixtures")
    return frame(0,0,0,1,0,0,0,math.cos(x),-math.sin(x),0,math.sin(x),math.cos(x))
end}
local Vector3={new=function(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0,Magnitude=math.sqrt((x or 0)^2+(y or 0)^2+(z or 0)^2)} end}
local function sameFrame(a,want)
    for i=1,12 do assert(math.abs(a[i]-want[i])<0.00001,"Unexpected CFrame component "..i..": "..tostring(a[i])) end
end
local methods={}
local function node(class,name)
    local props={Name=name or class,ClassName=class,children={},attributes={},ChildAdded=signal(),AncestryChanged=signal(),
        CFrame=frame(),Transform=frame(),Enabled=true,Archivable=true,Size={Y=2},Health=100}
    local object={kind="Instance",props=props}
    return setmetatable(object,{__index=function(_,key) return methods[key] or props[key] end,
        __newindex=function(_,key,value)
            props[key]=value
            if key=="Parent" and type(value)=="table" and value.kind=="Instance" then
                value.children[#value.children+1]=object;value.ChildAdded:fire(object)
            end
        end})
end
function methods:IsA(class)
    return self.ClassName==class or class=="Instance"
        or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart"))
        or (class=="JointInstance" and (self.ClassName=="Weld" or self.ClassName=="Motor6D"))
end
function methods:GetChildren() local all={};for _,v in ipairs(self.children) do if v.Parent==self then all[#all+1]=v end end;return all end
function methods:GetDescendants()
    local all={};local function visit(v) for _,child in ipairs(v:GetChildren()) do all[#all+1]=child;visit(child) end end
    visit(self);return all
end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(recursive and self:GetDescendants() or self:GetChildren()) do if child.Name==name then return child end end
end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self:GetChildren()) do if child:IsA(class) then return child end end end
function methods:Clone()
    local copy=node(self.ClassName,self.Name)
    for k,v in pairs(self.props) do if k~="children" and k~="Parent" and k~="ChildAdded" and k~="AncestryChanged" then copy[k]=v end end
    for _,child in ipairs(self:GetChildren()) do local cloned=child:Clone();cloned.Parent=copy end
    return copy
end
function methods:Destroy() for _,child in ipairs(self:GetChildren()) do child:Destroy() end;self.Parent=nil;self.destroyed=true end
function methods:Stop() self.stopped=true end
function methods:SetAttribute(k,v) self.attributes[k]=v end
function methods:GetAttribute(k) return self.attributes[k] end
local Instance={new=node}
local Enum={AnimationPriority={Core=0}}
local run
local contentProvider={PreloadAsync=function() end}
local game={GetService=function(_,name)
    if name=="RunService" then return run end
    if name=="ContentProvider" then return contentProvider end
    error("Unexpected service "..name)
end}
local function context(legacy)
    now=100;run={Stepped=signal(),Heartbeat=signal()};if not legacy then run.PreSimulation=signal() end
    contentProvider.PreloadAsync=function() end
    local reads,reports,listeners={},{},{}
    local ctx={config={AnimationClock="keyframes",Timeout=1,BootstrapTimeout=10},started=now,
        manifest={buildId="fixture"},catalog={animations={},packages={},hostedAnimations={}},report=function(msg) reports[#reports+1]=msg end}
    ctx.cleanup=cleanupFactory(ctx)
    ctx.network={now=function() return now end,on=function(_,key,fn) listeners[key]=fn;return function() listeners[key]=nil end end}
    ctx.state={onChanged=function(_,fn) return function() end end,all=function() return {} end,
        get=function(_,character) return {character=character,weapon="Bat"} end}
    local data={}
    data["assets/animations/locomotion.json"]={["walk/WalkAnim"]={Name="WalkAnim",AnimationId="fixture-original-gait",weight=10},
        ["idle/IdleAnim"]={Name="IdleAnim",AnimationId="fixture-original-idle",weight=10}}
    function ctx.json(path) reads[path]=(reads[path] or 0)+1;assert(data[path],"Missing test fixture "..path);return data[path] end
    local function sequence(key,legs)
        local poses={{name="Right Arm",parent="Torso",cframe={7,0,0,1,0,0,0,1,0,0,0,1},weight=1}}
        if legs then poses[#poses+1]={name="Left Leg",parent="Torso",cframe={12,0,0,1,0,0,0,1,0,0,0,1},weight=1} end
        local path="anim/"..key;ctx.catalog.animations[key]={path=path,sourcePlaybackSpeed=50}
        data[path]={frames={{time=0,poses=poses},{time=1,poses=poses}},duration=1,loop=false}
    end
    for _,key in ipairs({"bat/swing_1","bat/swing_2","bat/flourish","bat/unequip","other/carryGrabber"}) do sequence(key,false) end
    sequence("bat/swing_3",true);sequence("other/carryGrabbed",true)
    ctx.catalog.packages["audio/Equip"]={path="asset/equip",count=1}
    data["asset/equip"]={version=1,root="1",nodes={{id="1",class="Sound",name="Equip",properties={SoundId={type="string",value="fixture-original-sound"}}}}}
    return ctx,reads,reports,listeners
end
local character
local function walkingFigure(ctx,nativeMood)
    local c,_,arm,hip=character()
    local root=node("Part","HumanoidRootPart");root.Velocity=Vector3.new(14.5,0,0);root.Parent=c
    local head=node("MeshPart","Head");head.Parent=c
    local face=node("FaceControls","FaceControls");face.Parent=head;c:SetAttribute("FunCombatMoodAnimation",88)
    local hum=node("Humanoid","Humanoid");hum.Parent=c;hum.MoveDirection=Vector3.new()
    for _,key in ipairs({"Running","Jumping","Climbing","FreeFalling","Seated","Swimming","Died"}) do hum[key]=signal() end
    local tracks={}
    local function track(animation)
        local value=node("AnimationTrack","Track");value.Animation=animation;value.KeyframeReached=signal();value.Stopped=signal()
        function value:Play() self.played=true end
        function value:AdjustSpeed(speed) self.speed=speed end
        tracks[#tracks+1]=value;return value
    end
    if nativeMood then local a=node("Animation","OriginalMood");a.AnimationId="rbxassetid://88";track(a):Play() end
    function hum:LoadAnimation(animation) return track(animation) end
    function hum:GetPlayingAnimationTracks() local all={};for _,t in ipairs(tracks) do if t.played and not t.stopped then all[#all+1]=t end end;return all end
    ctx.state.all=function() return {[c]={character=c}} end
    return c,hum,tracks,arm,hip
end
function character()
    local c=node("Model","Actor");c.Parent=true
    local torso=node("Part","Torso");torso.Parent=c
    local arm=node("Part","Right Arm");arm.Parent=c
    local leg=node("Part","Left Leg");leg.Parent=c
    local shoulder=node("Motor6D","Right Shoulder");shoulder.Part0=torso;shoulder.Part1=arm;shoulder.Parent=torso
    local hip=node("Motor6D","Left Hip");hip.Part0=torso;hip.Part1=leg;hip.Parent=torso
    return c,arm,shoulder,hip
end
