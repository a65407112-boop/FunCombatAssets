-- Tiny API boundary for offline behavior tests. It does not simulate Roblox.
local M={}
function M.signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={_kind='RBXScriptConnection',Connected=true}
        function c:Disconnect()self.Connected=false;s.listeners[self]=nil end
        s.listeners[c]=fn;return c
    end
    function s:fire(...)
        local copy={};for c,fn in pairs(self.listeners)do copy[c]=fn end
        for c,fn in pairs(copy)do if c.Connected then fn(...)end end
    end
    return s
end
local parents={Part='BasePart',MeshPart='BasePart',UnionOperation='BasePart',TextButton='GuiButton',ImageButton='GuiButton',
    GuiButton='GuiObject',TextLabel='GuiObject',Frame='GuiObject',ScrollingFrame='GuiObject',ViewportFrame='GuiObject',
    Motor6D='JointInstance',Weld='JointInstance',ScreenGui='LayerCollector',BillboardGui='LayerCollector'}
local methods={}
function methods:IsA(cls)
    local at=self.ClassName
    while at do if at==cls then return true end;at=parents[at]end
    return cls=='Instance'
end
function methods:GetChildren()local out={};for _,v in ipairs(self._children)do out[#out+1]=v end;return out end
function methods:GetDescendants()
    local out={};local function walk(p)for _,c in ipairs(p._children)do out[#out+1]=c;walk(c)end end;walk(self);return out
end
function methods:FindFirstChild(name,recursive)
    for _,c in ipairs(self._children)do if c.Name==name then return c end end
    if recursive then for _,c in ipairs(self._children)do local r=c:FindFirstChild(name,true);if r then return r end end end
end
function methods:FindFirstChildWhichIsA(cls,recursive)
    for _,c in ipairs(self._children)do if c:IsA(cls)then return c end end
    if recursive then for _,c in ipairs(self._children)do local r=c:FindFirstChildWhichIsA(cls,true);if r then return r end end end
end
methods.FindFirstChildOfClass=methods.FindFirstChildWhichIsA
methods.WaitForChild=methods.FindFirstChild
function methods:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
function methods:GetPropertyChangedSignal(name)self._changed[name]=self._changed[name]or M.signal();return self._changed[name]end
function methods:Destroy()self.Parent=nil;self.Destroyed=true;for _,c in ipairs(self:GetChildren())do c:Destroy()end end
function methods:Stop()self.Stopped=true end
function methods:Clone()
    local c=M.object(self.ClassName,self.Name)
    for k,v in pairs(self._props)do if k~='Parent' then c[k]=v end end
    for _,child in ipairs(self._children)do child:Clone().Parent=c end;return c
end
function M.object(cls,name,parent)
    local o={_kind='Instance',_props={ClassName=cls,Name=name or cls,Enabled=true,Visible=true,Rotation=0},_children={},_changed={}}
    setmetatable(o,{__index=function(t,k)return methods[k]or t._props[k]end,__newindex=function(t,k,v)
        if k=='Parent' then
            local old=t._props.Parent;if old then for i,c in ipairs(old._children)do if c==t then table.remove(old._children,i);break end end end
            t._props.Parent=v;if v then v._children[#v._children+1]=t end
        else t._props[k]=v end
    end})
    o.ChildAdded=M.signal();o.AncestryChanged=M.signal();o.Activated=M.signal();o.MouseEnter=M.signal();o.MouseLeave=M.signal()
    o.CFrame=M.cf(0);o.Transform=M.cf(0);o.C0=M.cf(0);o.C1=M.cf(0);o.Grip=M.cf(0);o.Size={Y=2}
    o.Position={X={Scale=0,Offset=0},Y={Scale=0,Offset=0}};o.CanCollide=true;o.Anchored=false
    if parent then o.Parent=parent end;return o
end
local cf={};cf.__index=cf
function cf:Inverse()return M.cf(-self.value)end
function cf:ToObjectSpace(other)return M.cf(other.value-self.value)end
function cf:Lerp(other,a)return M.cf(self.value+(other.value-self.value)*a)end
cf.__mul=function(a,b)return M.cf(a.value+b.value)end
function M.cf(n)return setmetatable({value=n or 0},cf)end
local function enum()return setmetatable({},{__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end
function M.install()
    unpack=table.unpack;typeof=function(v)return type(v)=='table'and v._kind or type(v)end
    Enum=enum();CFrame={new=function(x)return M.cf(x or 0)end,Angles=function()return M.cf(0)end}
    UDim2={new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end}
    Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
    TweenInfo={new=function()return {}end};Instance={new=function(cls)return M.object(cls)end}
    local services={RunService={Heartbeat=M.signal(),RenderStepped=M.signal()},UserInputService={InputBegan=M.signal(),TouchTap=M.signal(),TouchEnabled=false,GetFocusedTextBox=function()end},
        TweenService={Create=function(_,obj,_,props)return {Completed=M.signal(),Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end}end}}
    game={GetService=function(_,name)return services[name]end};tick=function()return 0 end
    return services
end
return M
