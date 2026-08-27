-- FunCombat v2.3 exact source-place presentation assets.
-- Uses literal single-root RBXM objects extracted from the original place.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local ENV=(getgenv and getgenv()) or _G
local api=ENV.__FC_NATIVE_API
if not api then error("FunCombat v2.3: native API missing") end
local runtime=api.runtime
local connect=api.connect
local track=api.track
local status=api.status

local BASE="https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/client/"
local CACHE="FunCombatClientV23"
if type(writefile)~="function" then error("FunCombat v2.3 requires writefile") end
pcall(function()
    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder(CACHE)) then makefolder(CACHE) end
end)

local function nativeOne(name)
    status("v2.3 loading original "..name,false)
    local data=game:HttpGet(BASE..name.."?cb="..tostring(os.clock()))
    if type(data)~="string" or #data<32 or data:find("404: Not Found",1,true) then error("v2.3 download failed: "..name) end
    local path=CACHE.."/"..name
    writefile(path,data)
    task.wait(.05)
    local attempts={path,"./"..path}
    if type(getcustomasset)=="function" then
        local ok,a=pcall(getcustomasset,path);if ok and a then attempts[#attempts+1]=a end
    end
    local last
    for _,candidate in ipairs(attempts) do
        local ok,res=pcall(function()return game:GetObjects(candidate)end)
        if ok then
            if typeof(res)=="Instance" then return res end
            if type(res)=="table" and res[1] then return res[1] end
        else last=res end
    end
    error("v2.3 could not deserialize "..name..": "..tostring(last))
end

-- Remove the temporary v2/v2.2 billboards and install the exact Info hierarchy.
local infoTemplate=nativeOne("PlayerInfo_Original.rbxm")
if not infoTemplate:IsA("BillboardGui") or infoTemplate.Name~="Info" then error("v2.3 original Info RBXM root mismatch") end
infoTemplate.Parent=nil
local function genderColors(value)
    if value=="Female" then return Color3.fromRGB(170,86,162),Color3.fromRGB(35,23,34) end
    if value=="Male" then return Color3.fromRGB(27,175,158),Color3.fromRGB(26,42,53) end
    if value=="Fembxy" then return Color3.fromRGB(72,0,130),Color3.fromRGB(26,42,53) end
    return Color3.fromRGB(116,116,116),Color3.fromRGB(38,38,38)
end
local function installInfo(plr,char)
    local head=char:WaitForChild("Head",8);if not head then return end
    for _,n in ipairs({"__FunCombatInfo","Info"}) do local x=head:FindFirstChild(n);if x then x:Destroy() end end
    local info=infoTemplate:Clone();info.Adornee=head;info.Parent=head;track(info)
    local name=info:FindFirstChild("NameText")
    local gender=info:FindFirstChild("GenderText")
    if name then
        name.Text=plr.DisplayName
        local bg=name:FindFirstChild("Background");if bg and bg:IsA("TextLabel") then bg.Text=plr.DisplayName end
    end
    local function sync()
        if not gender then return end
        local value=tostring(plr:GetAttribute("Gender") or "N/A [N/A]")
        gender.Text=value
        local fg,bgcol=genderColors(plr:GetAttribute("Gender"));gender.TextColor3=fg
        local bg=gender:FindFirstChild("Background")
        if bg and bg:IsA("TextLabel") then bg.Text=value;bg.TextColor3=bgcol end
    end
    sync();connect(plr:GetAttributeChangedSignal("Gender"),sync)
end
local function hookInfo(plr)
    if plr.Character then task.spawn(installInfo,plr,plr.Character) end
    connect(plr.CharacterAdded,function(c)task.spawn(installInfo,plr,c)end)
end
for _,p in ipairs(Players:GetPlayers()) do hookInfo(p) end
connect(Players.PlayerAdded,hookInfo)

-- Replace the synthetic music object with the literal Workspace/Music object.
local old=workspace:FindFirstChild("__FCOriginalMusic");if old then old:Destroy() end
local old2=workspace:FindFirstChild("__FCExactMusic");if old2 then old2:Destroy() end
local music=nativeOne("Music_Original.rbxm")
music.Name="__FCExactMusic";music.Parent=workspace;track(music)
for _,d in ipairs(music:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then pcall(function()d.Disabled=true end) end end
local sound=music:FindFirstChild("currentSound")
if not sound or not sound:IsA("Sound") then error("v2.3 original currentSound missing") end
local playlist={1845341094,9046863253,9046864509,9043887091,1847506405,1837871067,1843468325,1845490105}
local musicToken=0
local function nextSong()
    if runtime.dead or not sound.Parent then return end
    musicToken+=1
    sound.SoundId="rbxassetid://"..playlist[math.random(1,#playlist)]
    sound.TimePosition=0
    sound:Play()
end
connect(sound.Ended,function()local t=musicToken;task.delay(3,function()if t==musicToken then nextSong() end end)end)
nextSong()

status("READY v2.3 | literal original Info + Music | original GUI/emotes/weapon presentation/leaning",false)
return true
