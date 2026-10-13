-- Separate manual, read-only diagnostic. The normal loader never executes it.
local Probe=(function()
--@FLIGHT_PROBE_MODULE@
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
