local M = {}
local RunService = game:GetService("RunService")
local active = setmetatable({}, {__mode="k"})
local function jointsForPose(rig, pose, parentPose, out)
    local parentPart = parentPose and rig:FindFirstChild(parentPose.Name, true)
    local posePart = rig:FindFirstChild(pose.Name, true)
    if parentPart and posePart then
        for _,j in ipairs(rig:GetDescendants()) do
            if j:IsA("Motor6D") and ((j.Part0==parentPart and j.Part1==posePart) or (j.Part1==parentPart and j.Part0==posePart)) then
                out[j]=pose.CFrame
                break
            end
        end
    end
    for _,sub in ipairs(pose:GetSubPoses()) do jointsForPose(rig,sub,pose,out) end
end
local function frameMap(rig,kf)
    local out={}
    for _,pose in ipairs(kf:GetPoses()) do jointsForPose(rig,pose,nil,out) end
    return out
end
function M.PlayAnimation(seq, rig)
    if not seq or not seq:IsA("KeyframeSequence") or not rig then return nil end
    local frames=seq:GetKeyframes(); table.sort(frames,function(a,b)return a.Time<b.Time end)
    if #frames==0 then return nil end
    local h={speed=1,dead=false,rig=rig}; active[h]=true
    task.spawn(function()
        local start=os.clock(); local duration=frames[#frames].Time
        while active[h] and not h.dead and rig.Parent do
            local t=(os.clock()-start)*h.speed
            if seq.Loop and duration>0 then t=t%duration elseif t>=duration then break end
            local a,b=frames[1],frames[#frames]
            for i=1,#frames-1 do if t>=frames[i].Time and t<=frames[i+1].Time then a,b=frames[i],frames[i+1];break end end
            local span=math.max(b.Time-a.Time,1/240); local alpha=math.clamp((t-a.Time)/span,0,1)
            local A=frameMap(rig,a); local B=frameMap(rig,b)
            for j,cf in pairs(A) do local to=B[j] or cf; if j.Parent then j.Transform=cf:Lerp(to,alpha) end end
            RunService.RenderStepped:Wait()
        end
        active[h]=nil
    end)
    return h
end
function M.StopAnimation(h) if type(h)=="table" then h.dead=true; active[h]=nil end end
function M.ChangeAnimationSpeed(h,s) if type(h)=="table" then h.speed=(tonumber(s) or 50)/50 end end
function M.StopAnimationOnHumanoid(hum)
    if not hum or not hum.Parent then return end
    for h in pairs(active) do if h.rig==hum.Parent then M.StopAnimation(h) end end
end
return M
