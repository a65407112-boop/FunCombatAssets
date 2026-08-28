local G=(getgenv and getgenv()) or _G
if G.FEAnimPackRunCleanup then pcall(G.FEAnimPackRunCleanup) end

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local charConn, guiConn, viewConn
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
        for _,track in ipairs(animator:GetPlayingAnimationTracks()) do pcall(function() track:Stop(0.08) end) end
    end
end

local restored=false
local function restoreAnimate()
    if restored then return end
    restored=true
    if charConn then charConn:Disconnect() end
    if guiConn then guiConn:Disconnect() end
    if viewConn then viewConn:Disconnect() end
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

if gui then
    guiConn=gui.AncestryChanged:Connect(function(_,parent)
        if parent==nil then restoreAnimate() end
    end)

    local main=gui:FindFirstChildOfClass("Frame")
    local camera=Workspace.CurrentCamera

    if main and camera then
        -- Keep the window inside the phone/tablet viewport.
        local function fitToScreen(recenter)
            local viewport=camera.ViewportSize
            local width=math.min(430, math.max(300, viewport.X-20))
            local height=math.min(520, math.max(300, viewport.Y-28))
            main.Size=UDim2.fromOffset(width,height)

            if recenter then
                local x=math.max(0, math.floor((viewport.X-width)/2))
                local y=math.max(0, math.floor((viewport.Y-height)/2))
                main.Position=UDim2.fromOffset(x,y)
            else
                local pos=main.AbsolutePosition
                local maxX=math.max(0,viewport.X-width)
                local maxY=math.max(0,viewport.Y-height)
                main.Position=UDim2.fromOffset(math.clamp(pos.X,0,maxX),math.clamp(pos.Y,0,maxY))
            end
        end

        fitToScreen(true)
        viewConn=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            task.defer(function()
                if main and main.Parent then fitToScreen(false) end
            end)
        end)

        -- Dedicated drag layer. The original desktop drag code can miss touch-move events.
        local dragHandle=Instance.new("TextButton")
        dragHandle.Name="MobileDragHandle"
        dragHandle.Text=""
        dragHandle.AutoButtonColor=false
        dragHandle.BackgroundTransparency=1
        dragHandle.Active=true
        dragHandle.Size=UDim2.new(1,-58,0,44)
        dragHandle.Position=UDim2.fromOffset(0,0)
        dragHandle.ZIndex=25
        dragHandle.Parent=main

        local dragging=false
        local dragInput=nil
        local dragStart=nil
        local startAbs=nil

        local function updateDrag(input)
            if not dragging or not dragStart or not startAbs then return end
            local delta=input.Position-dragStart
            local viewport=camera.ViewportSize
            local size=main.AbsoluteSize
            local x=math.clamp(startAbs.X+delta.X,0,math.max(0,viewport.X-size.X))
            local y=math.clamp(startAbs.Y+delta.Y,0,math.max(0,viewport.Y-size.Y))
            main.Position=UDim2.fromOffset(x,y)
        end

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=true
                dragInput=input
                dragStart=input.Position
                startAbs=main.AbsolutePosition

                input.Changed:Connect(function()
                    if input.UserInputState==Enum.UserInputState.End then
                        dragging=false
                        dragInput=nil
                    end
                end)
            end
        end)

        dragHandle.InputChanged:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement then
                dragInput=input
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if dragging and input==dragInput then
                updateDrag(input)
            end
        end)

        UIS.InputEnded:Connect(function(input)
            if input==dragInput or input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=false
                dragInput=nil
            end
        end)
    end
end
