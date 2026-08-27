    local first=tostring(path):match("^([^/]+)");local file=first and animFiles[first];if not file then return nil end
    if animLoading[file] then while animLoading[file] do task.wait() end;return findPath(animations,path) end
    if not animLoaded[file] then
        animLoading[file]=true;status("loading animations: "..first,false)
        local ok,err=pcall(function()mount(file,animations)end);animLoading[file]=nil;if not ok then error(err) end;animLoaded[file]=true
    end
    return findPath(animations,path)
end

-- Manual KeyframeSequence player. This follows the original AnimationManager/
-- AnimationPlayer from the source place instead of the earlier approximation.
local movementControllers=setmetatable({},{__mode="k"})
local active=setmetatable({},{__mode="k"})
local function getJointBetween(part0,part1)
    if not part0 or not part1 then return nil end
    for _,o in ipairs(part1:GetChildren()) do if o:IsA("Motor6D") and o.Part0==part0 then return o end end
    for _,o in ipairs(part0:GetChildren()) do if o:IsA("Motor6D") and o.Part1==part1 then return o end end
end
local function findRigPart(rig,name)
    for _,p in ipairs(rig:GetDescendants()) do
        if p:IsA("BasePart") and not p:FindFirstAncestorWhichIsA("Accessory") and p.Name==name then return p end
    end
end
local function resetRig(rig)
    if not rig then return end
    for _,j in ipairs(rig:GetDescendants()) do if j:IsA("Motor6D") then pcall(function()j.Transform=CFrame.new()end) end end
end
local Anim={}
function Anim.PlayAnimation(seq,rig)
    if not seq or not seq:IsA("KeyframeSequence") or not rig or not rig.Parent then return nil end
    -- Original manager permits one manual animation per humanoid.
    for h in pairs(active) do if h.rig==rig then Anim.StopAnimation(h) end end
    local frames=seq:GetKeyframes();table.sort(frames,function(a,b)return a.Time<b.Time end);if #frames==0 then return nil end
    local h={rig=rig,seq=seq,frames=frames,index=1,speed=50,dead=false,last={},desired={},base={}}
    active[h]=true
    local move=movementControllers[rig];if move then move:pause() end
    local function updatePositions()
        table.clear(h.desired)
        local kf=h.frames[h.index];if not kf then return 0 end
        local function recurse(parentPose,pose)
            if parentPose then
                local p0=findRigPart(rig,parentPose.Name);local p1=findRigPart(rig,pose.Name)
                local joint=getJointBetween(p0,p1)
                if joint then
                    if h.base[joint]==nil then h.base[joint]=joint.Transform end
                    h.last[joint]=joint.Transform;h.desired[joint]=pose.CFrame
                end
            end
            for _,sub in ipairs(pose:GetSubPoses()) do recurse(pose,sub) end
        end
        for _,pose in ipairs(kf:GetPoses()) do recurse(nil,pose) end
        return kf.Time
    end
    local timeNeeded=updatePositions();local t=0
    h.connection=RunService.Stepped:Connect(function(_,step)
        if h.dead or not rig.Parent then return end
        t=t+(step*h.speed)
        local alpha=timeNeeded==0 and 1 or math.min(1,t/math.max(.001,timeNeeded))
        for joint,pos in pairs(h.desired) do if joint.Parent then joint.Transform=(h.last[joint] or CFrame.new()):Lerp(pos,alpha) end end
        if alpha>=1 then
            for joint,pos in pairs(h.desired) do h.last[joint]=pos end
            h.index+=1
            if h.index>#h.frames then
                if seq.Loop then h.index=1 else Anim.StopAnimation(h);return end
            end
            timeNeeded=updatePositions();t=0
        end
    end)
    table.insert(runtime.connections,h.connection)
    return h
end
function Anim.StopAnimation(h)
    if type(h)~="table" or h.dead then return end
    h.dead=true;active[h]=nil
    if h.connection then pcall(function()h.connection:Disconnect()end) end
    resetRig(h.rig)
    local move=movementControllers[h.rig];if move then task.defer(function()if h.rig and h.rig.Parent then move:resume() end end) end
end
function Anim.ChangeAnimationSpeed(h,s) if type(h)=="table" then h.speed=tonumber(s) or 50 end end
function Anim.StopCharacter(char) for h in pairs(active) do if h.rig==char then Anim.StopAnimation(h) end end end

status("loading all GUI roots",false)
local guiRoots=import("StarterGui.rbxm")
local guiCount=#guiRoots
for _,root in ipairs(guiRoots) do freezeLocals(root);root:SetAttribute("__FunCombatImported",true);root.Parent=pg;track(root) end

-- v2.1 loads StarterPlayer directly to avoid the Xeno packing stall. If only the
-- first root is exposed, PlayerScripts still load and the exact classic fallback
-- below supplies character movement without fighting manual emote/combat poses.
status("loading player roots",false)
local charScriptsTemplate;local importedPlayerRoots={};local starterRoots=import("StarterPlayer.rbxm")
for _,root in ipairs(starterRoots) do
    freezeLocals(root)
    if root.Name=="StarterPlayerScripts" then
        local ps=player:WaitForChild("PlayerScripts")
        for _,c in ipairs(root:GetChildren()) do freezeLocals(c);c:SetAttribute("__FunCombatImported",true);c.Parent=ps;track(c);importedPlayerRoots[#importedPlayerRoots+1]=c end
        root:Destroy()
    elseif root.Name=="StarterCharacterScripts" then charScriptsTemplate=root
    elseif root:IsA("Model") and root.Name=="StarterCharacter" then track(root) end
end

local function fallbackR6(char)
    if char:GetAttribute("__FCFallbackAnimate") then return end
    char:SetAttribute("__FCFallbackAnimate",true)
    local hum=char:FindFirstChildOfClass("Humanoid");if not hum then return end
    local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
    local tracks={};local current;local paused=false;local lastMove=0
    local function load(key,id,priority,looped)
        local a=Instance.new("Animation");a.AnimationId="rbxassetid://"..id
        local ok,t=pcall(function()return animator:LoadAnimation(a)end);a:Destroy()
        if ok and t then t.Priority=priority;t.Looped=looped;tracks[key]=t end
    end
    load("idle","180435571",Enum.AnimationPriority.Core,true)
    load("walk","180426354",Enum.AnimationPriority.Core,true)
    load("jump","125750702",Enum.AnimationPriority.Core,false)
    load("fall","180436148",Enum.AnimationPriority.Core,true)
    load("climb","180436334",Enum.AnimationPriority.Core,true)
    load("sit","178130996",Enum.AnimationPriority.Core,true)
    local function play(k,fade,speed)
        if paused then return end
        local t=tracks[k];if not t then return end
        if current~=t then if current then pcall(function()current:Stop(fade or .1)end) end;current=t;pcall(function()t:Play(fade or .1)end) end
        if speed then pcall(function()t:AdjustSpeed(speed)end) end
    end
    local ctl={}
    function ctl:pause() paused=true;if current then pcall(function()current:Stop(.05)end) end;current=nil end
    function ctl:resume()
        paused=false
        if hum.FloorMaterial==Enum.Material.Air then play("fall",.1,1)
        elseif hum.MoveDirection.Magnitude>.03 then play("walk",.1,math.max(.2,hum.WalkSpeed/14.5))
        else play("idle",.1,1) end
    end
    movementControllers[char]=ctl
    connect(hum.Running,function(speed)
        if paused then return end
        if speed>.25 then lastMove=os.clock();play("walk",.1,math.max(.2,speed/14.5))
        elseif speed<.05 then
            local stamp=lastMove;task.delay(.08,function()if not paused and lastMove==stamp and hum.MoveDirection.Magnitude<.02 then play("idle",.1,1) end end)
        end
    end)
