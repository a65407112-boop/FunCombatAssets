-- Null Protocol UI/gameplay action bridge v9
-- Opens are handled by v8. This file wires the actual emote requests and
-- completes server-approved weapon delivery. Gameplay authority stays server-side.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")
local ENV=(getgenv and getgenv()) or _G

local function status(text,bad)
    print("[Null Protocol v9] "..tostring(text))
    local g=pg:FindFirstChild("__NPBootstrap")
    local l=g and g:FindFirstChildWhichIsA("TextLabel",true)
    if l then
        l.Text="Null Protocol: "..tostring(text)
        l.BackgroundColor3=bad and Color3.fromRGB(100,20,20) or Color3.fromRGB(20,70,35)
    end
end

local function findEither(parent,clearName,tokenName)
    if not parent then return nil end
    return parent:FindFirstChild(clearName) or (tokenName and parent:FindFirstChild(tokenName))
end

local remotes=findEither(RS,"Remotes","xaf2bb0d97d5d")
local emoteRemote=findEither(remotes,"Emote","x5988a13e5f9e")
local bus=findEither(remotes,"TestAnimation","xe40a2326dbcf")
local equipRemote=remotes and remotes:FindFirstChild("EquipWeapon")

-- EMOTES ---------------------------------------------------------------------
-- Mirror the original controller exactly at the network boundary: a TextButton
-- under Emotes.display sends its Instance.Name to the server. The client does
-- not play an emote by itself; it waits for the server visual-bus A opcode.
local pendingEmote=nil

task.spawn(function()
    local gui=pg:WaitForChild("Emotes",10)
    local display=gui and gui:FindFirstChild("display")
    if not gui or not display then
        status("v9: Emotes display missing",true)
        return
    end
    if not emoteRemote or not emoteRemote:IsA("RemoteEvent") then
        status("v9: SERVER Emote remote missing",true)
        return
    end

    local count=0
    for _,button in ipairs(display:GetDescendants()) do
        if button:IsA("TextButton") and not button:GetAttribute("__NPV9EmoteAction") then
            count+=1
            button:SetAttribute("__NPV9EmoteAction",true)
            button.Activated:Connect(function()
                local char=plr.Character
                if not char then return end

                -- Preserve the original gameplay locks without inventing state.
                if char:FindFirstChild("qbfd8b3bf7ac864d9") then
                    status("emote blocked by server stun state",true)
                    return
                end
                if char:FindFirstChild("q811f2132e7542a42") then
                    status("emote blocked while carrying",true)
                    return
                end
                if char:GetAttribute("q9e5fe3c6a1262529")==true then
                    status("emote blocked by server state",true)
                    return
                end

                local requestName=button.Name
                pendingEmote={name=requestName,char=char,t=os.clock()}
                status("emote request sent -> "..requestName,false)
                emoteRemote:FireServer(requestName)

                local ticket=pendingEmote
                task.delay(4,function()
                    if pendingEmote==ticket then
                        pendingEmote=nil
                        status("EMOTE SENT BUT NO SERVER A ACK: "..requestName,true)
                    end
                end)
            end)
        end
    end
    if count==0 then
        status("v9: no emote TextButtons found",true)
    else
        print("[Null Protocol v9] wired "..count.." emote buttons")
    end
end)

-- WEAPONS --------------------------------------------------------------------
local weaponGui=pg:FindFirstChild("weapon")
local weaponAnimLoaded=false
local weaponBusy=false

local function findWeaponTool(name)
    local menu=weaponGui or pg:FindFirstChild("weapon")
    if not menu then return nil end
    for _,v in ipairs(menu:GetDescendants()) do
        if v:IsA("Tool") and v.Name==name then return v end
    end
    return nil
end

-- v7 already sends EquipWeapon from weapon buttons when that server remote is
-- present. Install a request controller only if that button was NOT wired by v7.
task.spawn(function()
    weaponGui=pg:WaitForChild("weapon",10)
    if not weaponGui then
        status("v9: weapon menu missing",true)
        return
    end

    for _,button in ipairs(weaponGui:GetDescendants()) do
        if button:IsA("TextButton") then
            local tool=button:FindFirstChildWhichIsA("Tool",true)
            if tool and not button:GetAttribute("__NPWeaponRequest") and not button:GetAttribute("__NPV9WeaponRequest") then
                button:SetAttribute("__NPV9WeaponRequest",true)
                button.Activated:Connect(function()
                    if not equipRemote or not equipRemote:IsA("RemoteEvent") then
                        status("WEAPON REQUEST FAILED: server EquipWeapon missing",true)
                        return
                    end
                    status("weapon request sent -> "..tool.Name,false)
                    equipRemote:FireServer(tool.Name)
                end)
            end
        end
    end
end)

if bus and bus:IsA("RemoteEvent") then
    bus.OnClientEvent:Connect(function(op,...)
        local a={...}

        -- A is the server's animation order. If it targets our character while
        -- an emote request is pending, that is the acknowledgement we care about.
        if op=="A" and pendingEmote then
            local path=a[2]
            local target=a[3]
            if target==pendingEmote.char then
                local name=pendingEmote.name
                pendingEmote=nil
                status("emote ACK <- server: "..name.." | "..tostring(path),false)
            end
            return
        end

        -- EQ means the SERVER approved this weapon. Only now do we load its heavy
        -- animation pack and materialize the local presentation Tool in Backpack.
        if op=="EQ" then
            if weaponBusy then return end
            weaponBusy=true
            local name=tostring(a[1])
            task.spawn(function()
                status("weapon ACK <- server: "..name,false)

                if not weaponAnimLoaded then
                    local loadAnim=ENV.__NULL_LOAD_ANIM
                    if type(loadAnim)~="function" then
                        status("WEAPON ACK BUT animation loader missing",true)
                        weaponBusy=false
                        return
                    end
                    status("server approved weapon; loading weapon animations",false)
                    local okAnim,animErr=loadAnim("anim_bat.lua")
                    if not okAnim then
                        status("weapon animation load failed: "..tostring(animErr),true)
                        weaponBusy=false
                        return
                    end
                    weaponAnimLoaded=true
                end

                local tool=findWeaponTool(name)
                if not tool then
                    status("SERVER APPROVED WEAPON BUT TOOL NOT FOUND: "..name,true)
                    weaponBusy=false
                    return
                end

                local backpack=plr:WaitForChild("Backpack")
                tool.Parent=backpack
                if weaponGui then weaponGui.Enabled=false end

                task.wait(.1)
                if tool.Parent==backpack then
                    status("weapon issued -> Backpack: "..name,false)
                else
                    status("weapon approval received but Backpack move failed: "..name,true)
                end
                weaponBusy=false
            end)
        end
    end)
else
    status("v9: server visual bus missing; emote/weapon ACK unavailable",true)
end

return true
