    task.spawn(function()local seq=ensureAnimation("bat/flourish");if seq and c.Parent then Anim.PlayAnimation(seq,c) end end)
end
for _,p in ipairs(Players:GetPlayers()) do task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"));connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"))end) end
connect(Players.PlayerAdded,function(p)connect(p:GetAttributeChangedSignal("EquippedWeapon"),function()task.defer(presentWeapon,p,p:GetAttribute("EquippedWeapon"))end)end)

-- Server visual bus: native KeyframeSequences, sounds and simple effects.
local handles={}
local changer;pcall(function()changer=require(RS:WaitForChild("NewChanger"))end)
local function localSound(id,target,start,duration,speed)
    if not target or typeof(target)~="Instance" or not id then return end
    local s=Instance.new("Sound");s.SoundId=tostring(id);s.Parent=target;if start then pcall(function()s.TimePosition=start end) end;if speed then s.PlaybackSpeed=speed end;s:Play();Debris:AddItem(s,duration or 12)
end
local function namedSound(name,target,start,duration,speed)
    local root=RS:FindFirstChild("Sounds");local src=root and root:FindFirstChild(tostring(name),true)
    if src and src:IsA("Sound") and target then local c=src:Clone();c.Parent=target;if start then pcall(function()c.TimePosition=start end) end;if speed then c.PlaybackSpeed=speed end;c:Play();Debris:AddItem(c,duration or 12) end
end
local function flash(char,fill,outline,duration)
    if not char then return end;local h=Instance.new("Highlight");h.FillColor=fill or Color3.new(1,1,1);h.OutlineColor=outline or Color3.new();h.FillTransparency=.25;h.Parent=char
    TweenService:Create(h,TweenInfo.new(duration or .5),{FillTransparency=1,OutlineTransparency=1}):Play();Debris:AddItem(h,duration or .5)
end
local function hitEffect(victim,name,parent)
    local vfx=RS:FindFirstChild("VFX");local hits=vfx and vfx:FindFirstChild("Hits");local dest=parent or (victim and (victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")))
    if not hits or not dest then return end;local t=hits:FindFirstChild(tostring(name),true);if not t then return end;local c=t:Clone();c.Parent=dest
    for _,e in ipairs(c:GetDescendants()) do if e:IsA("ParticleEmitter") then e:Emit(e:GetAttribute("EmitCount") or 1) end end;Debris:AddItem(c,5)
end
connect(bus.OnClientEvent,function(op,...)
    local a={...}
    if op=="A" then
        local id,path,char=a[1],a[2],a[3]
        task.spawn(function()
            local seq=ensureAnimation(path)
            if seq and char and char.Parent then if handles[id] then Anim.StopAnimation(handles[id]) end;handles[id]=Anim.PlayAnimation(seq,char) else warn("[FC] animation missing "..tostring(path)) end
        end)
    elseif op=="AS" then local h=handles[a[1]];if h then Anim.StopAnimation(h);handles[a[1]]=nil end
    elseif op=="AV" then local h=handles[a[1]];if h then Anim.ChangeAnimationSpeed(h,a[2]) end
    elseif op=="ASTOPCHAR" then Anim.StopCharacter(a[1])
    elseif op=="S" then localSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="SN" then namedSound(a[1],a[2],a[3],a[4],a[5])
    elseif op=="HS" then namedSound(a[1],a[2] and (a[2]:FindFirstChild("HumanoidRootPart") or a[2]))
    elseif op=="F" then flash(a[1],a[2],a[3],a[4])
    elseif op=="H" then hitEffect(a[1],a[2],a[3])
    elseif op=="M+" then if changer then pcall(function()changer:loadMorph(a[1],a[2])end) end
    elseif op=="M-" then if changer then pcall(function()changer:clearMorph(a[1],a[2])end) end
    elseif op=="EQ" then local p,n=a[1],a[2];if typeof(p)=="Instance" and p:IsA("Player") then presentWeapon(p,n) end end
end)

ENV.__FC_NATIVE_API={
    ensureAnimation=ensureAnimation,
    Anim=Anim,
    remotes=remotes,
    runtime=runtime,
    status=status,
    player=player,
    playerGui=pg,
    connect=connect,
    track=track,
}
status(string.format("READY | GUI=%d/17 | locals=%d started=%d unreadable=%d failed=%d",guiCount,runtime.localFound,runtime.localStarted,runtime.localUnreadable,runtime.localFailed),guiCount~=17)
return true
