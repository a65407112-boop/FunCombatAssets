-- Separate manual, read-only diagnostic. The normal loader never executes it.
local Probe=(function()
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

end)()
local env=type(getgenv)=='function'and getgenv()or _G
local key='__FunCombatFlightProbe_v1'
if env[key]and env[key].destroy then pcall(env[key].destroy)end
local session={cancelled=false,ticket=0};env[key]=session
local Players=game:GetService('Players');local Http=game:GetService('HttpService');local player=Players.LocalPlayer
assert(player,'Flight diagnostic needs LocalPlayer')
local gui=Instance.new('ScreenGui');gui.Name='FunCombatFlightDiagnostic';gui.ResetOnSpawn=false
local parent=player:FindFirstChildOfClass('PlayerGui')or game:GetService('CoreGui')
if type(gethui)=='function'then local ok,p=pcall(gethui);if ok and typeof(p)=='Instance'then parent=p end end
gui.Parent=parent
local frame=Instance.new('Frame');frame.Size=UDim2.new(0,300,0,250);frame.Position=UDim2.new(0,12,1,-262)
frame.BackgroundColor3=Color3.fromRGB(24,27,34);frame.BorderSizePixel=0;frame.Parent=gui
local status=Instance.new('TextLabel');status.Size=UDim2.new(1,-16,0,40);status.Position=UDim2.new(0,8,0,6);status.BackgroundTransparency=1
status.TextColor3=Color3.new(1,1,1);status.Font=Enum.Font.SourceSans;status.TextSize=15;status.TextWrapped=true;status.Parent=frame
local box=Instance.new('TextBox');box.Size=UDim2.new(1,-16,0,126);box.Position=UDim2.new(0,8,0,48);box.MultiLine=true;box.ClearTextOnFocus=false
box.TextSize=10;box.Font=Enum.Font.Code;box.TextColor3=Color3.new(1,1,1);box.BackgroundColor3=Color3.fromRGB(35,38,47);box.TextWrapped=true;box.Parent=frame
local connections={};local report={kind='portable_flight_probe',liveClientSnapshot=true,readOnly=true,samples={}}
local function update()
    report.summary=Probe.summary(report.samples);report.buildReports={}
    local runtime=env.__FunCombatPortable_v1
    if runtime and type(runtime.reports)=='table'then for i=math.max(1,#runtime.reports-19),#runtime.reports do report.buildReports[#report.buildReports+1]=runtime.reports[i]end end
    local ok,body=pcall(function()return Http:JSONEncode(report)end);box.Text=ok and body or 'Report encoding failed: '..tostring(body)
end
local function capture()
    local ok,snapshot=pcall(Probe.capture,env.__FunCombatPortable_v1,{player=player,workspace=workspace,clock=tick})
    if ok then report.samples[#report.samples+1]=snapshot else report.errors=report.errors or {};report.errors[#report.errors+1]=tostring(snapshot)end
end
local function record()
    session.ticket=session.ticket+1;local ticket=session.ticket
    session.recording=true;box.Text='Recording; the new report will be available after 10 seconds.'
    report={kind='portable_flight_probe',liveClientSnapshot=true,readOnly=true,atUtc=os.date('!%Y-%m-%dT%H:%M:%SZ'),userId=player.UserId,placeId=game.PlaceId,samples={}}
    coroutine.wrap(function()
        local started=tick()
        while not session.cancelled and ticket==session.ticket and tick()-started<10 do
            capture();status.Text='Recording '..tostring(math.max(0,10-math.floor(tick()-started)))..'s: reproduce the flight';wait(0.16)
        end
        if session.cancelled or ticket~=session.ticket then return end
        session.recording=false;update();status.Text='Ready. Copy report and send it.'
    end)()
end
function session.destroy()
    if session.cancelled then return end;session.cancelled=true
    for _,c in ipairs(connections)do c:Disconnect()end
    gui:Destroy();if env[key]==session then env[key]=nil end
end
local function button(label,x,width,fn)
    local b=Instance.new('TextButton');b.Text=label;b.Size=UDim2.new(0,width,0,28);b.Position=UDim2.new(0,x,0,181)
    b.Font=Enum.Font.SourceSans;b.TextSize=14;b.Parent=frame;connections[#connections+1]=b.Activated:Connect(fn)
end
button('Record 10s',8,100,record)
button('Copy report',114,108,function()
    if session.recording then status.Text='Still recording. Wait for Ready, then copy the new report.';return end
    local copy=setclipboard or toclipboard or (syn and syn.setclipboard)
    if type(copy)=='function'then local ok,why=pcall(copy,box.Text);status.Text=ok and 'Copied. Send this report.'or 'Copy failed: '..tostring(why)
    else status.Text='Clipboard API unavailable. Select the report text and copy.';box:CaptureFocus()end
end)
button('Close',228,64,session.destroy)
local note=Instance.new('TextLabel');note.Size=UDim2.new(1,-16,0,30);note.Position=UDim2.new(0,8,0,216);note.BackgroundTransparency=1
note.Text='Reads character/proxy state; does not move them.';note.TextColor3=Color3.new(1,1,1);note.Font=Enum.Font.SourceSans;note.TextSize=12;note.TextWrapped=true;note.Parent=frame
capture();update();status.Text='Press Record 10s, then reproduce the flight.'
return session
