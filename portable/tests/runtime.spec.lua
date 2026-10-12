local ok,Visibility=pcall(dofile,"portable/visibility.lua")
assert(ok,"Local visibility ownership module must exist")
local Appearance=dofile("portable/appearance.lua")
local signals={};local values={LocalTransparencyModifier=0,Health=83,CFrame="real-root"}
local object=setmetatable({}, {__index=function(_,k)
    if k=="GetPropertyChangedSignal" then return function(_,name)
        signals[name]=signals[name] or {}
        return {Connect=function(_,fn)local t={fn=fn};signals[name][t]=true;return {Disconnect=function()signals[name][t]=nil end}end}
    end end
    return values[k]
end,__newindex=function(_,k,v)values[k]=v;for t in pairs(signals[k] or {})do t.fn()end end})
local guard=Visibility.new();assert(guard:set(object,"LocalTransparencyModifier",1));assert(values.LocalTransparencyModifier==1)
object.LocalTransparencyModifier=0.25;assert(values.LocalTransparencyModifier==1)
guard:destroy();assert(values.LocalTransparencyModifier==0.25)
assert(values.Health==83 and values.CFrame=="real-root","Visibility must not change actual health or root")
local source={parts={Head={Color="head"},UpperTorso={Color="torso"},LeftUpperArm={Color="arm"}}}
function source:FindFirstChild(name)return self.parts[name]end
function source:FindFirstChildOfClass(name)return name=="BodyColors" and self.colors or nil end
assert(Appearance.color(source,"Torso","fallback")=="torso")
assert(Appearance.color(source,"Left Arm","fallback")=="arm")
assert(Appearance.color(source,"Right Leg","fallback")=="fallback")
source.colors={TorsoColor3="rgb-metadata",HeadColor3="head-metadata"}
assert(Appearance.color(source,"Torso","fallback")=="rgb-metadata")
assert(Appearance.color(source,"Head","fallback")=="head-metadata")
local mounting={Parent=nil};local current=mounting
assert(not Appearance.current(mounting,function()return current end),"Unmounted CharacterAdded must wait")
mounting.Parent=true;assert(Appearance.current(mounting,function()return current end))
current={Parent=true};assert(not Appearance.current(mounting,function()return current end),"Late spawn result must reject old character")
print("RUNTIME OWNERSHIP TESTS 8")
local function item(class,name,parent)return {ClassName=class,Name=name,Parent=parent}end
local src={};src.Head={}
function src:FindFirstChild(name)return name=='Head' and self.Head or nil end
assert(Appearance.affects(item('Shirt','Shirt',src),src),'Late clothing must trigger synchronization')
assert(Appearance.affects(item('Accessory','Hair',src),src),'Late accessory must trigger synchronization')
assert(Appearance.affects(item('Decal','face',src.Head),src),'Late face must trigger synchronization')
assert(not Appearance.affects(item('Motor6D','Hip',src),src),'Ordinary movement must not rebuild avatars')
print('LATE APPEARANCE TESTS 4')
