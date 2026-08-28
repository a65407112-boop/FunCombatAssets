-- FEAnimPack loader / GUI
-- R6 raw KeyframeSequence player. No AnimationId required.
-- Visibility to other players depends on Roblox/game replication. This is not a server bypass.

local G = (getgenv and getgenv()) or _G
if G.FEAnimPackCleanup then pcall(G.FEAnimPackCleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
if not player then return end

local BASE = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/"
local ok, Animations = pcall(function()
    return loadstring(game:HttpGet(BASE .. "animations.lua"))()
end)
if not ok or type(Animations) ~= "table" then
    warn("[FEAnimPack] animations.lua failed to load:", Animations)
    return
end

local gui = Instance.new("ScreenGui")
gui.Name = "FEAnimPack"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

local function round(obj, r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=obj; return c
end
local function button(parent, text, pos, size)
    local b=Instance.new("TextButton")
    b.Position=pos; b.Size=size; b.BackgroundColor3=Color3.fromRGB(45,45,53); b.BorderSizePixel=0
    b.Text=text; b.TextColor3=Color3.fromRGB(242,242,246); b.Font=Enum.Font.GothamBold; b.TextSize=13
    b.Parent=parent; round(b,8); return b
end

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(430,520); main.Position=UDim2.new(.5,-215,.5,-260)
main.BackgroundColor3=Color3.fromRGB(21,21,25); main.BorderSizePixel=0; main.Parent=gui; round(main,12)
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(112,112,130); stroke.Transparency=.45; stroke.Parent=main

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-56,0,42); title.Position=UDim2.fromOffset(14,0); title.BackgroundTransparency=1
title.Text="FE ANIMS  •  R6  •  50"; title.TextColor3=Color3.fromRGB(245,245,248); title.Font=Enum.Font.GothamBold
title.TextSize=17; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=main
local close=button(main,"×",UDim2.new(1,-42,0,6),UDim2.fromOffset(34,30)); close.TextSize=20

local search=Instance.new("TextBox")
search.Size=UDim2.new(1,-28,0,36); search.Position=UDim2.fromOffset(14,48); search.BackgroundColor3=Color3.fromRGB(34,34,40)
search.BorderSizePixel=0; search.Text=""; search.PlaceholderText="Search animation or category..."; search.ClearTextOnFocus=false
search.TextColor3=Color3.fromRGB(245,245,248); search.PlaceholderColor3=Color3.fromRGB(125,125,140); search.Font=Enum.Font.Gotham
search.TextSize=13; search.Parent=main; round(search,8)

local stop=button(main,"STOP",UDim2.fromOffset(14,92),UDim2.fromOffset(92,34))
local minus=button(main,"−",UDim2.fromOffset(114,92),UDim2.fromOffset(34,34)); minus.TextSize=18
local speedLabel=Instance.new("TextLabel")
speedLabel.Size=UDim2.fromOffset(104,34); speedLabel.Position=UDim2.fromOffset(154,92); speedLabel.BackgroundColor3=Color3.fromRGB(34,34,40)
speedLabel.BorderSizePixel=0; speedLabel.Text="Speed 1.00x"; speedLabel.TextColor3=Color3.fromRGB(220,220,227); speedLabel.Font=Enum.Font.Gotham
speedLabel.TextSize=12; speedLabel.Parent=main; round(speedLabel,8)
local plus=button(main,"+",UDim2.fromOffset(264,92),UDim2.fromOffset(34,34)); plus.TextSize=18
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-316,0,34); status.Position=UDim2.fromOffset(306,92); status.BackgroundTransparency=1; status.Text="Idle"
status.TextColor3=Color3.fromRGB(150,150,164); status.Font=Enum.Font.Gotham; status.TextSize=11; status.TextXAlignment=Enum.TextXAlignment.Right; status.Parent=main

local list=Instance.new("ScrollingFrame")
list.Size=UDim2.new(1,-28,1,-146); list.Position=UDim2.fromOffset(14,136); list.BackgroundColor3=Color3.fromRGB(27,27,32)
list.BorderSizePixel=0; list.ScrollBarThickness=6; list.CanvasSize=UDim2.new(); list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.Parent=main; round(list,10)
local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=list
local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,6); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=list

-- drag window
local dragging=false; local dragStart; local startPos
title.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=main.Position end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

local character, humanoid, joints
local current, startedAt, speed = nil, 0, 1
local renderConn, charConn

local function motor(parent,name)
    if not parent then return end
    local d=parent:FindFirstChild(name)
    if d and d:IsA("Motor6D") then return d end
    for _,v in ipairs(parent:GetDescendants()) do if v:IsA("Motor6D") and v.Name==name then return v end end
end
local function bind(char)
    character=char; humanoid=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
    if not humanoid then return false end
    if humanoid.RigType~=Enum.HumanoidRigType.R6 then status.Text="R6 required"; joints=nil; return false end
    local torso=char:FindFirstChild("Torso") or char:WaitForChild("Torso",5)
    local root=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5)
    if not torso or not root then return false end
    joints={
        Root=motor(root,"RootJoint") or motor(torso,"RootJoint"), Neck=motor(torso,"Neck"),
        RightArm=motor(torso,"Right Shoulder"), LeftArm=motor(torso,"Left Shoulder"),
        RightLeg=motor(torso,"Right Hip"), LeftLeg=motor(torso,"Left Hip")
    }
    for _,j in pairs(joints) do if j then j.Transform=CFrame.new() end end
    return true
end
local function resetPose()
    if joints then for _,j in pairs(joints) do if j then j.Transform=CFrame.new() end end end
end
local function C(v)
    if not v then return CFrame.new() end
    return CFrame.new(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],v[12])
end
local function interp(a,b,t)
    a=a or {}; b=b or {}
    return {
        Root=C(a.Root):Lerp(C(b.Root),t), Torso=C(a.Torso):Lerp(C(b.Torso),t), Head=C(a.Head):Lerp(C(b.Head),t),
        RightArm=C(a.RightArm):Lerp(C(b.RightArm),t), LeftArm=C(a.LeftArm):Lerp(C(b.LeftArm),t),
        RightLeg=C(a.RightLeg):Lerp(C(b.RightLeg),t), LeftLeg=C(a.LeftLeg):Lerp(C(b.LeftLeg),t)
    }
end
local function sample(anim,t)
    local f=anim.frames
    if t<=f[1].t then return interp(f[1].p,f[1].p,0) end
    if t>=f[#f].t then return interp(f[#f].p,f[#f].p,0) end
    for i=1,#f-1 do
        local a,b=f[i],f[i+1]
        if t>=a.t and t<=b.t then
            local span=b.t-a.t; local alpha=span>0 and (t-a.t)/span or 0
            return interp(a.p,b.p,alpha)
        end
    end
    return interp(f[#f].p,f[#f].p,0)
end
local function apply(p)
    if not joints then return end
    if joints.Root then joints.Root.Transform=(p.Root or CFrame.new())*(p.Torso or CFrame.new()) end
    if joints.Neck then joints.Neck.Transform=p.Head end
    if joints.RightArm then joints.RightArm.Transform=p.RightArm end
    if joints.LeftArm then joints.LeftArm.Transform=p.LeftArm end
    if joints.RightLeg then joints.RightLeg.Transform=p.RightLeg end
    if joints.LeftLeg then joints.LeftLeg.Transform=p.LeftLeg end
end
local function stopAnim() current=nil; status.Text="Idle"; resetPose() end
local function play(anim)
    if not character or not character.Parent then bind(player.Character or player.CharacterAdded:Wait()) end
    if not joints then return end
    current=anim; startedAt=os.clock(); status.Text=anim.name
end

renderConn=RunService.RenderStepped:Connect(function()
    if not current or not joints then return end
    local d=math.max(current.duration or 0,.001); local t=(os.clock()-startedAt)*speed
    if current.looped then t=t%d elseif t>=d then apply(sample(current,d)); current=nil; status.Text="Finished"; return end
    apply(sample(current,t))
end)

local entries={}
for i,anim in ipairs(Animations) do
    local b=button(list,"",UDim2.new(),UDim2.new(1,0,0,42)); b.LayoutOrder=i
    local n=Instance.new("TextLabel"); n.Size=UDim2.new(1,-105,1,0); n.Position=UDim2.fromOffset(12,0); n.BackgroundTransparency=1
    n.Text=anim.name; n.TextColor3=Color3.fromRGB(240,240,245); n.Font=Enum.Font.GothamMedium; n.TextSize=13; n.TextXAlignment=Enum.TextXAlignment.Left; n.Parent=b
    local c=Instance.new("TextLabel"); c.Size=UDim2.fromOffset(95,42); c.Position=UDim2.new(1,-103,0,0); c.BackgroundTransparency=1
    c.Text=anim.category or ""; c.TextColor3=Color3.fromRGB(140,140,154); c.Font=Enum.Font.Gotham; c.TextSize=10; c.TextXAlignment=Enum.TextXAlignment.Right; c.Parent=b
    b.MouseButton1Click:Connect(function() play(anim) end)
    entries[#entries+1]={button=b,anim=anim}
end
local function filter()
    local q=string.lower(search.Text or "")
    for _,e in ipairs(entries) do
        local h=string.lower(e.anim.name.." "..(e.anim.category or ""))
        e.button.Visible=(q=="" or string.find(h,q,1,true)~=nil)
    end
end
search:GetPropertyChangedSignal("Text"):Connect(filter)
stop.MouseButton1Click:Connect(stopAnim)
local function setSpeed(v)
    speed=math.clamp(math.floor(v*4+.5)/4,.25,3)
    speedLabel.Text=string.format("Speed %.2fx",speed)
    if current then startedAt=os.clock() end
end
minus.MouseButton1Click:Connect(function() setSpeed(speed-.25) end)
plus.MouseButton1Click:Connect(function() setSpeed(speed+.25) end)
charConn=player.CharacterAdded:Connect(function(char) task.wait(.4); bind(char); stopAnim() end)
if player.Character then bind(player.Character) end

local cleaned=false
local function cleanup()
    if cleaned then return end; cleaned=true
    stopAnim(); if renderConn then renderConn:Disconnect() end; if charConn then charConn:Disconnect() end
    if gui then gui:Destroy() end; G.FEAnimPackCleanup=nil
end
G.FEAnimPackCleanup=cleanup
close.MouseButton1Click:Connect(cleanup)
print("[FEAnimPack] loaded "..tostring(#Animations).." animations")
