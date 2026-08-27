    local first=tostring(path):match("^([^/]+)");local file=first and animFiles[first];if not file then return nil end
    if animLoading[file] then while animLoading[file] do task.wait() end;return findPath(animations,path) end
    if not animLoaded[file] then
        animLoading[file]=true;status("loading animations: "..first,false)
        local ok,err=pcall(function()mount(file,animations)end);animLoading[file]=nil;if not ok then error(err) end;animLoaded[file]=true
    end
    return findPath(animations,path)
end

-- KeyframeSequence player used for the native exported sequences.
local active=setmetatable({},{__mode="k"})
local function jointsForPose(rig,pose,parentPose,out)
    local parentPart=parentPose and rig:FindFirstChild(parentPose.Name,true)
    local posePart=rig:FindFirstChild(pose.Name,true)
    if parentPart and posePart then
        for _,j in ipairs(rig:GetDescendants()) do
            if j:IsA("Motor6D") and ((j.Part0==parentPart and j.Part1==posePart) or (j.Part1==parentPart and j.Part0==posePart)) then out[j]=pose.CFrame;break end
        end
    end
    for _,sub in ipairs(pose:GetSubPoses()) do jointsForPose(rig,sub,pose,out) end
end
local function frameMap(rig,kf)
    local out={};for _,pose in ipairs(kf:GetPoses()) do jointsForPose(rig,pose,nil,out) end;return out
end
local function resetRig(rig)
    if not rig then return end
    for _,j in ipairs(rig:GetDescendants()) do if j:IsA("Motor6D") then pcall(function()j.Transform=CFrame.new()end) end end
end
local Anim={}
function Anim.PlayAnimation(seq,rig)
    if not seq or not seq:IsA("KeyframeSequence") or not rig then return nil end
    local frames=seq:GetKeyframes();table.sort(frames,function(a,b)return a.Time<b.Time end);if #frames==0 then return nil end
    local h={speed=1,dead=false,rig=rig};active[h]=true
    task.spawn(function()
        local start=os.clock();local duration=frames[#frames].Time
        while active[h] and not h.dead and rig.Parent do
            local t=(os.clock()-start)*h.speed
            if seq.Loop and duration>0 then t=t%duration elseif t>=duration then break end
            local a,b=frames[1],frames[#frames]
            for i=1,#frames-1 do if t>=frames[i].Time and t<=frames[i+1].Time then a,b=frames[i],frames[i+1];break end end
            local span=math.max(b.Time-a.Time,1/240);local alpha=math.clamp((t-a.Time)/span,0,1)
            local A=frameMap(rig,a);local B=frameMap(rig,b)
            for j,cf in pairs(A) do if j.Parent then j.Transform=cf:Lerp(B[j] or cf,alpha) end end
            RunService.RenderStepped:Wait()
        end
        active[h]=nil;if not h.dead then resetRig(rig) end
    end)
    return h
end
function Anim.StopAnimation(h) if type(h)=="table" then h.dead=true;active[h]=nil;resetRig(h.rig) end end
function Anim.ChangeAnimationSpeed(h,s) if type(h)=="table" then h.speed=(tonumber(s) or 50)/50 end end
function Anim.StopCharacter(char) for h in pairs(active) do if h.rig==char then Anim.StopAnimation(h) end end end

-- Mount all GUI roots. This is the bug fixed in v2: expect 17, not one.
status("loading all GUI roots",false)
local guiRoots=import("StarterGui.rbxm")
local guiCount=#guiRoots
for _,root in ipairs(guiRoots) do freezeLocals(root);root:SetAttribute("__FunCombatImported",true);root.Parent=pg;track(root) end

-- StarterPlayer has three roots. Move PlayerScripts, retain character script templates.
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

-- Reveal server proxy characters and restore the original classic movement scripts
-- when their Source can be executed. If not, use a tiny stock-R6 fallback.
local function fallbackR6(char)
    if char:GetAttribute("__FCFallbackAnimate") then return end
    char:SetAttribute("__FCFallbackAnimate",true)
    local hum=char:FindFirstChildOfClass("Humanoid");if not hum then return end
    local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
    local tracks={}
    local function load(key,id,priority,looped)
        local a=Instance.new("Animation");a.AnimationId="rbxassetid://"..id
        local ok,t=pcall(function()return animator:LoadAnimation(a)end);a:Destroy()
        if ok and t then t.Priority=priority;t.Looped=looped;tracks[key]=t end
    end
    load("idle","180435571",Enum.AnimationPriority.Idle,true)
    load("walk","180426354",Enum.AnimationPriority.Movement,true)
    load("jump","125750702",Enum.AnimationPriority.Movement,false)
    load("fall","180436148",Enum.AnimationPriority.Movement,true)
    local current
    local function play(k,speed)
        local t=tracks[k];if not t or current==t then if t and speed then t:AdjustSpeed(speed) end;return end
        if current then pcall(function()current:Stop(.15)end) end;current=t;pcall(function()t:Play(.15);if speed then t:AdjustSpeed(speed) end end)
    end
