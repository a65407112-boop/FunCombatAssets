-- Null Protocol UI hotfix v8
-- Fixes menu presentation only. Gameplay/emote/weapon decisions remain server-side.

local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")

local function status(text,bad)
    print("[Null Protocol v8] "..tostring(text))
    local g=pg:FindFirstChild("__NPBootstrap")
    local l=g and g:FindFirstChildWhichIsA("TextLabel",true)
    if l then
        l.Text="Null Protocol: "..tostring(text)
        l.BackgroundColor3=bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,70,35)
    end
end

local function forceLater(fn)
    task.defer(fn)
    task.delay(.06,fn)
    task.delay(.18,fn)
    task.delay(.55,fn)
end

-- WEAPON MENU
-- The exported weaponGui LocalScript and an older compatibility fallback can both
-- toggle weapon.Enabled. Keep our own desired state and force that state after
-- all same-click callbacks have had time to run.
task.spawn(function()
    local openerGui=pg:WaitForChild("weaponGui",10)
    local menu=pg:WaitForChild("weapon",10)
    if not openerGui or not menu then
        status("v8: weapon GUI missing",true)
        return
    end

    local desired=menu.Enabled
    local found=0
    for _,b in ipairs(openerGui:GetDescendants()) do
        if b:IsA("GuiButton") and not b:GetAttribute("__NPV8WeaponOpen") then
            found+=1
            b:SetAttribute("__NPV8WeaponOpen",true)
            b.Activated:Connect(function()
                desired=not desired
                local target=desired
                forceLater(function()
                    if menu and menu.Parent then menu.Enabled=target end
                end)
                status(target and "weapon menu OPEN" or "weapon menu CLOSED",false)
            end)
        end
    end
    if found==0 then status("v8: weapon opener button missing",true) end
end)

-- EMOTES MENU
-- Original layout does not disable the ScreenGui. It moves the display frame:
-- off-screen Y=1.3 <-> visible Y=0.6. Reproduce that exact presentation rule.
task.spawn(function()
    local gui=pg:WaitForChild("Emotes",10)
    if not gui then
        status("v8: Emotes GUI missing",true)
        return
    end
    gui.Enabled=true

    local buttonFrame=gui:FindFirstChild("button")
    local display=gui:FindFirstChild("display")
    local opener=buttonFrame and buttonFrame:FindFirstChildWhichIsA("GuiButton",true)
    if not display or not display:IsA("GuiObject") or not opener then
        status("v8: Emotes opener/display missing",true)
        return
    end

    local offPos=UDim2.new(.5,0,1.3,0)
    local onPos=UDim2.new(.5,0,.6,0)
    local desiredOpen=display.Position.Y.Scale < 1

    opener:SetAttribute("__NPV8EmoteOpen",true)
    opener.Activated:Connect(function()
        desiredOpen=not desiredOpen
        local open=desiredOpen
        local target=open and onPos or offPos

        -- Force final state after any reconstructed callback. Use the original
        -- 0.5 second Sine/Out motion for the first pass, then snap final state.
        task.defer(function()
            if display and display.Parent then
                display.Visible=true
                pcall(function()
                    TweenService:Create(display,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Position=target}):Play()
                end)
            end
        end)
        task.delay(.58,function()
            if display and display.Parent then
                display.Visible=true
                display.Position=target
            end
        end)
        status(open and "emotes menu OPEN" or "emotes menu CLOSED",false)
    end)
end)

return true
