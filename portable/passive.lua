-- Own only the visual model. Refuse an active Humanoid instead of hiding errors.
local P={}
function P.prepareHumanoid(humanoid)
    local ok,why=pcall(function()
        humanoid.EvaluateStateMachine=false
        assert(humanoid.EvaluateStateMachine==false,'readback stayed enabled')
        humanoid.AutoRotate=false
    end)
    if not ok then return false,'Cannot disable proxy Humanoid simulation: '..tostring(why)end
    return true
end
function P.install(model,humanoid,scope,onFault)
    local ok,why=P.prepareHumanoid(humanoid);assert(ok,why)
    local guard={parts={},busy={},dead=false,failed=false,repairs=0}
    local function fault(message)
        if guard.failed or guard.dead then return end
        guard.failed=true;onFault(tostring(message))
    end
    local function repair(part)
        if guard.dead or guard.failed or guard.busy[part]or not part.Parent or not part:IsDescendantOf(model)then return end
        guard.busy[part]=true
        local done,errorMessage=pcall(function()
            if not part.Anchored then part.Anchored=true;guard.repairs=guard.repairs+1 end
            if part.CanCollide then part.CanCollide=false;guard.repairs=guard.repairs+1 end
            assert(part.Anchored and not part.CanCollide,'part flags refused passivity')
            pcall(function()part.CanTouch=false;part.CanQuery=false end)
        end)
        guard.busy[part]=nil
        if not done then fault('Unsafe local visual part: '..part.Name..': '..tostring(errorMessage))end
    end
    local function watch(object)
        if not object:IsA('BasePart')or guard.parts[object]then return end
        local partScope=scope:scope();guard.parts[object]=partScope;repair(object)
        partScope:add(object:GetPropertyChangedSignal('CanCollide'):Connect(function()repair(object)end))
        partScope:add(object:GetPropertyChangedSignal('Anchored'):Connect(function()repair(object)end))
    end
    function guard:check()
        if self.dead or self.failed then return false end
        local read,value=pcall(function()return humanoid.EvaluateStateMachine end)
        if not read or value~=false then
            if self.checkingHumanoid then return false end
            self.checkingHumanoid=true;local disabled,errorMessage=P.prepareHumanoid(humanoid);self.checkingHumanoid=false
            if not disabled then fault(errorMessage);return false end
            self.repairs=self.repairs+1
        end
        for part in pairs(self.parts)do repair(part)end
        return not self.failed
    end
    for _,object in ipairs(model:GetDescendants())do watch(object)end
    scope:add(model.DescendantAdded:Connect(watch))
    scope:add(model.DescendantRemoving:Connect(function(object)
        local partScope=guard.parts[object];guard.parts[object]=nil;guard.busy[object]=nil
        if partScope then partScope:destroy()end
    end))
    scope:add(humanoid:GetPropertyChangedSignal('EvaluateStateMachine'):Connect(function()guard:check()end))
    scope:add(function()guard.dead=true;guard.parts={};guard.busy={}end)
    assert(not guard.failed,'Proxy passivity initialization failed')
    return guard
end
return P
