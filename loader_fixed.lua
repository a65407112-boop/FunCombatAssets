-- Null Protocol stable loader hotfix
-- Keeps the existing runtime build, repairs its patcher, and installs a
-- reliable Gender fallback after the GUI has been created.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G
ENV.__NULL_ALLOW_RIG = false

local BASE_COMMIT = "https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/5129021c5eccb630a12ffeba79742bb393c5e569/"
local src = game:HttpGet(BASE_COMMIT .. "loader.lua?cb=" .. tostring(os.clock()))

-- 1) Fix the chunked-mount patch. A function replacement means '%' is just a
-- normal character and can never be interpreted as a gsub capture reference.
local oldChunk = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%%200==0 then task.wait() end",
        2
    )]]

local newChunk = [[    src,replacements=src:gsub(
        "for _,n in ipairs%(pack%.nodes%) do",
        function()
            return "for __rt_i,n in ipairs(pack.nodes) do if __rt_i%25==0 then task.wait() end"
        end,
        2
    )]]

local p = src:find(oldChunk, 1, true)
if not p then
    error("Null Protocol hotfix: chunked-mount patch point not found")
end
src = src:sub(1, p - 1) .. newChunk .. src:sub(p + #oldChunk)

-- 2) Do not start the ~9k-object rig pack two seconds after boot. That load was
-- racing the first menu click and looked exactly like the button froze Roblox.
local oldRigStart = [[task.spawn(function()
    task.wait(2)
    print("[Null Protocol] loading rig_assets.lua")]]

local newRigStart = [[task.spawn(function()
    while not (((getgenv and getgenv()) or _G).__NULL_ALLOW_RIG) do
        task.wait(.1)
    end
    task.wait(2)
    print("[Null Protocol] loading rig_assets.lua")]]

local rp = src:find(oldRigStart, 1, true)
if not rp then
    error("Null Protocol hotfix: rig-load gate patch point not found")
end
src = src:sub(1, rp - 1) .. newRigStart .. src:sub(rp + #oldRigStart)

local fn, err = loadstring(src, "NullProtocolFixedLoader")
if not fn then
    error("Null Protocol hotfix compile failed: " .. tostring(err))
end

local result = fn()

-- 3) Reliable Gender handling. The original Gender LocalScript lives inside
-- data/starter_gui.lua, so trying to patch its source in core.lua never touched
-- it. Handle the actual GuiButtons after the runtime mounts them instead.
task.spawn(function()
    local pg = plr:WaitForChild("PlayerGui", 10)
    if not pg then
        ENV.__NULL_ALLOW_RIG = true
        return
    end

    local gender = pg:WaitForChild("Gender", 10)
    if not gender then
        ENV.__NULL_ALLOW_RIG = true
        return
    end

    local attributeName = "qe8be68a176690a76"

    -- If the server already knows the choice, never show the selector again.
    if plr:GetAttribute(attributeName) then
        gender.Enabled = false
        task.delay(1, function() ENV.__NULL_ALLOW_RIG = true end)
        return
    end

    gender.Enabled = true
    local handled = false

    local function choose(button)
        if handled then return end
        handled = true

        -- Hide immediately so UI feedback never waits on network latency.
        gender.Enabled = false

        -- Repeat the server request as a fallback in case the exported
        -- Buttons LocalScript failed or had not connected yet.
        local attributeSystem = RS:FindFirstChild("AttributeSystem")
        local setInfo = attributeSystem and attributeSystem:FindFirstChild("SetInfo")
        if setInfo and setInfo:IsA("RemoteEvent") then
            pcall(function()
                setInfo:FireServer(attributeName, button.Text)
            end)
        end

        task.spawn(function()
            local deadline = os.clock() + 4
            while os.clock() < deadline and not plr:GetAttribute(attributeName) do
                task.wait(.05)
            end

            if not plr:GetAttribute(attributeName) then
                warn("[Null Protocol] Gender UI closed, but server confirmation did not arrive")
                local reporter = ENV.__NULL_REPORT
                if reporter then
                    pcall(reporter, "Gender selected locally; server confirmation timed out")
                end
            end

            -- Give the menu time to disappear before mounting thousands of
            -- visual instances. This prevents the first click from looking frozen.
            task.wait(2)
            ENV.__NULL_ALLOW_RIG = true
        end)
    end

    local count = 0
    for _, v in ipairs(gender:GetDescendants()) do
        if v:IsA("GuiButton") and (v.Name == "Male" or v.Name == "Female" or v.Name == "Fembxy") then
            count = count + 1
            v.Activated:Connect(function()
                choose(v)
            end)
        end
    end

    if count == 0 then
        warn("[Null Protocol] Gender buttons not found; allowing rig load")
        ENV.__NULL_ALLOW_RIG = true
    end
end)

return result
