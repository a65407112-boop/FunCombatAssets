local G=(getgenv and getgenv()) or _G
if G.FEAnimPackRunCleanup then pcall(G.FEAnimPackRunCleanup) end

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local charConn, guiConn, viewConn
local extraConnections={}
local touched={}

local function silence(char)
    if not char then return end
    local animate=char:FindFirstChild("Animate")
    if animate then
        touched[animate]=animate.Disabled
        animate.Disabled=true
    end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local animator=hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.08) end)
        end
    end
end

local restored=false
local function restoreAnimate()
    if restored then return end
    restored=true
    if charConn then charConn:Disconnect() end
    if guiConn then guiConn:Disconnect() end
    if viewConn then viewConn:Disconnect() end
    for _,c in ipairs(extraConnections) do pcall(function() c:Disconnect() end) end
    for animate,wasDisabled in pairs(touched) do
        if animate and animate.Parent then animate.Disabled=wasDisabled end
    end
    G.FEAnimPackRunCleanup=nil
end
G.FEAnimPackRunCleanup=restoreAnimate

silence(player.Character)
charConn=player.CharacterAdded:Connect(function(char)
    task.wait(0.35)
    silence(char)
end)

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/"
local src=game:HttpGet(BASE.."loader.lua")
src=src:gsub('BASE %.%. "animations%.lua"','BASE .. "animations_runtime.lua"')
local fn,compileErr=loadstring(src)
if not fn then restoreAnimate(); error(compileErr) end
local ok,runErr=pcall(fn)
if not ok then restoreAnimate(); error(runErr) end

local playerGui=player:FindFirstChildOfClass("PlayerGui")
local gui=CoreGui:FindFirstChild("FEAnimPack") or (playerGui and playerGui:FindFirstChild("FEAnimPack"))
if not gui then return end

guiConn=gui.AncestryChanged:Connect(function(_,parent)
    if parent==nil then restoreAnimate() end
end)

local main=gui:FindFirstChildOfClass("Frame")
local camera=Workspace.CurrentCamera
if not main or not camera then return end

-- Make the menu fit phones and tablets.
local function fitToScreen(recenter)
    local viewport=camera.ViewportSize
    local width=math.min(430, math.max(280, viewport.X-16))
    local height=math.min(520, math.max(280, viewport.Y-20))
    main.Size=UDim2.fromOffset(width,height)

    if recenter then
        main.Position=UDim2.fromOffset(
            math.max(0,math.floor((viewport.X-width)/2)),
            math.max(0,math.floor((viewport.Y-height)/2))
        )
    else
        local p=main.AbsolutePosition
        main.Position=UDim2.fromOffset(
            math.clamp(p.X,0,math.max(0,viewport.X-width)),
            math.clamp(p.Y,0,math.max(0,viewport.Y-height))
        )
    end
end
fitToScreen(true)
viewConn=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    task.defer(function()
        if main and main.Parent then fitToScreen(false) end
    end)
end)

-- Big explicit drag control for mobile. It sits above the title so the old
-- desktop drag handler in loader.lua never receives this touch.
local move=Instance.new("TextButton")
move.Name="MoveHandle"
move.Size=UDim2.fromOffset(112,34)
move.Position=UDim2.new(.5,-56,0,4)
move.BackgroundColor3=Color3.fromRGB(58,58,69)
move.BorderSizePixel=0
move.Text="☰  MOVE"
move.TextColor3=Color3.fromRGB(245,245,248)
move.Font=Enum.Font.GothamBold
move.TextSize=12
move.AutoButtonColor=false
move.Active=true
move.ZIndex=100
move.Parent=main
local mc=Instance.new("UICorner")
mc.CornerRadius=UDim.new(0,8)
mc.Parent=move

local dragging=false
local activeTouch=nil
local startTouch=nil
local startWindow=nil

local function moveFrom(screenPos)
    if not dragging or not startTouch or not startWindow then return end
    local delta=screenPos-startTouch
    local viewport=camera.ViewportSize
    local size=main.AbsoluteSize
    local x=math.clamp(startWindow.X+delta.X,0,math.max(0,viewport.X-size.X))
    local y=math.clamp(startWindow.Y+delta.Y,0,math.max(0,viewport.Y-size.Y))
    main.Position=UDim2.fromOffset(x,y)
end

-- Start drag on the MOVE control.
extraConnections[#extraConnections+1]=move.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        activeTouch=input
        startTouch=input.Position
        startWindow=main.AbsolutePosition
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        activeTouch=nil
        startTouch=input.Position
        startWindow=main.AbsolutePosition
    end
end)

-- Direct mobile events. These are much more reliable than generic InputChanged
-- on several Android executors.
extraConnections[#extraConnections+1]=UIS.TouchMoved:Connect(function(input)
    if dragging and activeTouch then
        -- Some executors wrap touch InputObjects strangely, so do not require
        -- strict object identity here. While MOVE is held, the moving finger wins.
        moveFrom(input.Position)
    end
end)
extraConnections[#extraConnections+1]=UIS.TouchEnded:Connect(function(input)
    if dragging and activeTouch then
        dragging=false
        activeTouch=nil
        startTouch=nil
        startWindow=nil
    end
end)

-- Desktop fallback.
extraConnections[#extraConnections+1]=UIS.InputChanged:Connect(function(input)
    if dragging and not activeTouch and input.UserInputType==Enum.UserInputType.MouseMovement then
        moveFrom(input.Position)
    end
end)
extraConnections[#extraConnections+1]=UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and not activeTouch then
        dragging=false
        startTouch=nil
        startWindow=nil
    end
end)

print("[FEAnimPack] mobile drag v3 ready")
