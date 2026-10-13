-- Read-only snapshot helpers. Used only by the separate manual diagnostic.
local P={}
local function read(o,key)if not o then return nil end;local ok,v=pcall(function()return o[key]end);if ok then return v end end
local function name(o)if not o then return nil end;local ok,v=pcall(function()return o:GetFullName()end);return ok and v or read(o,'Name')end
local function vector(v)
    if not v then return nil end
    local x,y,z=read(v,'X'),read(v,'Y'),read(v,'Z')
    if type(x)~='number'or type(y)~='number'or type(z)~='number'or x~=x or y~=y or z~=z or math.abs(x)==math.huge or math.abs(y)==math.huge or math.abs(z)==math.huge then return nil end
    return {x=x,y=y,z=z}
end
local function offset(a,b)
    if not a or not b then return nil end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function part(p)
    if not p then return nil end
    return {name=name(p),position=vector(read(p,'Position')),velocity=vector(read(p,'AssemblyLinearVelocity')or read(p,'Velocity')),
        anchored=read(p,'Anchored'),canCollide=read(p,'CanCollide'),assemblyRoot=name(read(p,'AssemblyRootPart'))}
end
local function humanoid(h)
    if not h then return nil end
    local ok,state=pcall(function()return h:GetState().Name end)
    return {state=ok and state or nil,health=read(h,'Health'),walkSpeed=read(h,'WalkSpeed'),platformStand=read(h,'PlatformStand'),sit=read(h,'Sit'),
        evaluateStateMachine=read(h,'EvaluateStateMachine'),moveDirection=vector(read(h,'MoveDirection'))}
end
function P.capture(runtime,api)
    local player=api.player;local character=player and player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart');local h=character and character:FindFirstChildOfClass('Humanoid')
    local r=runtime and runtime.avatars and runtime.avatars:getLocal();local e=r and r.avatar
    local camera=api.workspace and api.workspace.CurrentCamera
    local out={at=api.clock(),runtimePresent=type(runtime)=='table',initialized=runtime and runtime.initialized or false,
        buildId=runtime and runtime.portableManifest and runtime.portableManifest.buildId,
        source={character=name(character),root=part(root),humanoid=humanoid(h)},camera={subject=name(camera and camera.CameraSubject),position=vector(camera and camera.CFrame.Position)}}
    if e then
        out.proxy={character=name(e.model),root=part(e.parts.HumanoidRootPart),torso=part(e.parts.Torso),head=part(e.parts.Head),
            humanoid=humanoid(e.model:FindFirstChildOfClass('Humanoid')),collidableParts=0,unanchoredParts=0,collidingNames={},
            ragdolled=r.ragdolled,downed=r.downed,dashing=r.dashing,weapon=r.weapon,
            guardRepairs=e.passive and e.passive.repairs,guardFailed=e.passive and e.passive.failed}
        for _,p in ipairs(e.model:GetDescendants())do
            if p:IsA('BasePart')then
                if p.CanCollide then out.proxy.collidableParts=out.proxy.collidableParts+1;if #out.proxy.collidingNames<24 then out.proxy.collidingNames[#out.proxy.collidingNames+1]=p.Name end end
                if not p.Anchored then out.proxy.unanchoredParts=out.proxy.unanchoredParts+1 end
            end
        end
        local sourcePosition=out.source.root and out.source.root.position
        out.delta={proxyRootToSource=offset(out.proxy.root and out.proxy.root.position,sourcePosition),torsoToSource=offset(out.proxy.torso and out.proxy.torso.position,sourcePosition)}
        out.connectedProxyParts={}
        if root then
            pcall(function()
                for _,p in ipairs(root:GetConnectedParts(true))do if p:IsDescendantOf(e.model)then out.connectedProxyParts[#out.connectedProxyParts+1]=name(p)end end
            end)
        end
        if api.workspace.CurrentCamera then out.camera.subjectIsProxy=api.workspace.CurrentCamera.CameraSubject and api.workspace.CurrentCamera.CameraSubject:IsDescendantOf(e.model)or false end
    end
    if root then
        out.source.forces={}
        for _,o in ipairs(character:GetDescendants())do
            if o:IsA('BodyMover')or o:IsA('AlignPosition')or o:IsA('LinearVelocity')or o:IsA('VectorForce')then
                if #out.source.forces<20 then out.source.forces[#out.source.forces+1]={name=name(o),class=o.ClassName,velocity=vector(read(o,'Velocity')or read(o,'VectorVelocity')),maxForce=vector(read(o,'MaxForce')),enabled=read(o,'Enabled')}end
            end
        end
    end
    return out
end
function P.summary(samples)
    local result={samples=#samples,maxProxyRootOffset=0,maxTorsoOffset=0,proxyCollisionObserved=false,proxyUnanchoredObserved=false,realYMin=nil,realYMax=nil,maxAbsRealVerticalSpeed=0}
    for _,s in ipairs(samples)do
        local delta=s.delta or {};result.maxProxyRootOffset=math.max(result.maxProxyRootOffset,delta.proxyRootToSource or 0);result.maxTorsoOffset=math.max(result.maxTorsoOffset,delta.torsoToSource or 0)
        local p=s.proxy or {};result.proxyCollisionObserved=result.proxyCollisionObserved or (p.collidableParts or 0)>0;result.proxyUnanchoredObserved=result.proxyUnanchoredObserved or (p.unanchoredParts or 0)>0
        local source=s.source and s.source.root
        if source and source.position then local y=source.position.y;result.realYMin=result.realYMin and math.min(result.realYMin,y)or y;result.realYMax=result.realYMax and math.max(result.realYMax,y)or y end
        if source and source.velocity then result.maxAbsRealVerticalSpeed=math.max(result.maxAbsRealVerticalSpeed,math.abs(source.velocity.y))end
    end
    result.note='Observed positions/flags do not identify a cause by themselves; compare source, proxy, camera and forces.'
    return result
end
return P
