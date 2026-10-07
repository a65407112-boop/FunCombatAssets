-- Separate, manually run probe. Opening it only reads local metadata.
-- Test dummy requests ONE ordinary SpawnDummy and a read-only native KAI
-- command-registry reply. It never bypasses combat/admin checks or edits rigs.
-- Observations last 8 seconds; a missing reply is not proof of server rejection.
local DURATION=8
local environment=_G
if type(getgenv)=="function" then
    local ok,result=pcall(getgenv)
    if ok and type(result)=="table" then environment=result end
end
local function service(name)
    local ok,result=pcall(function() return game:GetService(name) end)
    return ok and result or nil
end
local function raw(object,key) return pcall(function() return object[key] end) end
local function read(object,key)
    local ok,result=raw(object,key)
    if not ok then return {unavailable=tostring(result)} end
    if result==nil then return "(nil)" end
    if type(result)=="string" or type(result)=="boolean" or type(result)=="number" then return result end
    return tostring(result)
end
local function fields(object,keys)
    local result={};for _,key in ipairs(keys) do result[key]=read(object,key) end;return result
end
local function find(parent,name,class)
    if not parent then return nil end
    local ok,result=pcall(function()
        if class then return parent:FindFirstChildOfClass(name) end
        return parent:FindFirstChild(name)
    end)
    return ok and result or nil
end
local function isA(object,class)
    local ok,result=pcall(function() return object:IsA(class) end)
    return ok and result==true
end
local function runtime()
    local ok,result=raw(environment,"FunCombat_ExternalRuntime")
    return ok and type(result)=="table" and result or nil
end
local players=service("Players")
local okPlayer,player=raw(players,"LocalPlayer");if not okPlayer then player=nil end
local storage,world=service("ReplicatedStorage"),service("Workspace")
local function snapshot(ctx)
    local character=player and player.Character
    local flag=find(find(world,"Configuration"),"AllowDummys")
    local result={allowDummys=flag and fields(flag,{"ClassName","Value"}) or {missing=true},
        character=character and tostring(character) or "(nil)",
        humanoid=fields(find(character,"Humanoid",true),{"Health","RigType","PlatformStand"}),
        root=fields(find(character,"HumanoidRootPart"),{"Anchored"})}
    if ctx then
        result.runtime=fields(ctx,{"initialized","cancelled"})
        local stateOK,state=pcall(function() return ctx.state:localState() end)
        if stateOK and type(state)=="table" then
            result.localState=fields(state,{"health","downed","ragdolled","stunned","busy","canAct","carrying","carriedBy"})
            result.stateCharacterMatches=state.character==character
        else result.localState={unavailable=tostring(state)} end
    else result.runtime={missing=true} end
    return result
end
local previousStop=environment.FunCombatDummyDiagnosticsStop
if type(previousStop)=="function" then pcall(previousStop) end
local previousGUI=environment.FunCombatDummyDiagnosticsGUI
if previousGUI then pcall(function() previousGUI:Destroy() end) end
environment.FunCombatDummyDiagnosticsGUI=nil
local report={kind="manual_dummy_probe",durationSeconds=DURATION,
    creator=fields(game,{"CreatorId","CreatorType","PlaceId","GameId"}),
    user=fields(player,{"UserId","Name"}),before=snapshot(runtime()),
    probe={status="not_started",ownershipConfirmed=false},
    kohlRegistry={received=false,status="not_queried"},serverErrors={},newServerNPCs={},
    note="No request ID/owner acknowledgement exists in this protocol. A new NPC broadcast may belong to another player. No observed result is not a confirmed rejection. No Roblox engine test was run by the builder."}
pcall(function() report.atUtc=DateTime.now():ToIsoDate() end)
for _,key in ipairs({"FunCombatAdminAllowed","FunCombatAdminState","FunCombatAdminError","FunCombatAdminConfigError","FunCombatAdminSource"}) do
    local ok,result=pcall(function() return player:GetAttribute(key) end)
    if not ok then report.user[key]={unavailable=tostring(result)}
    elseif result==nil then report.user[key]="(nil)"
    else report.user[key]=result end
end
local connections,open,started,deadline={},true,false,nil
local gui,details,status,testButton,resize
local function disconnect()
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    connections={}
end
local function stop() open=false;disconnect() end
environment.FunCombatDummyDiagnosticsStop=stop
local function publish()
    if not open then return end
    local ok,text=pcall(function() return service("HttpService"):JSONEncode(report) end)
    if not ok then
        local function format(item,depth)
            if type(item)~="table" then return tostring(item) end
            if depth>8 then return "[depth limit]" end
            local keys={};for key in pairs(item) do keys[#keys+1]=key end
            table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
            local values={};for _,key in ipairs(keys) do values[#values+1]=tostring(key).."="..format(item[key],depth+1) end
            return "{"..table.concat(values,", ").."}"
        end
        text="JSON unavailable: "..tostring(text).."; "..format(report,0)
    end
    environment.FunCombatDummyDiagnostics=report;environment.FunCombatDummyDiagnosticsText=text
    if details then details.Text=text end
    if resize then resize(text) end
end
local function observe(signal,fn)
    local ok,connection=pcall(function() return signal:Connect(function(...)
        if not open or (deadline and tick()>=deadline) then return end
        local worked,why=pcall(fn,...)
        if not worked then report.observerError=tostring(why):sub(1,2000) end
    end) end)
    if ok then connections[#connections+1]=connection;return true end
    return false,tostring(connection)
end
local function start()
    if not open or started then return end
    started=true;deadline=tick()+DURATION;testButton.Text="Observing..."
    status.Text="One normal request; observing for 8 seconds. Then Copy report."
    local ctx=runtime()
    local character=player and player.Character
    report.before=snapshot(ctx);report.probe.status="running"
    local native=find(storage,"b\a\n\a\n\a")
    report.kohlRegistry={received=false,status="waiting"}
    if native and isA(native,"RemoteEvent") then
        local connected,why=observe(native.OnClientEvent,function(event,data)
            if event~="KuID" or type(data)~="table" or type(data[4])~="table" then return end
            local result={received=true,status="received",dummy=false,spawndummy=false,commandsScanned=0}
            if type(data[3])=="table" and data[3].Prefix~=nil then result.prefix=tostring(data[3].Prefix) end
            for index,command in ipairs(data[4]) do
                if index>2048 then result.truncated=true;break end
                result.commandsScanned=index
                if type(command)=="table" and type(command[1])=="table" then
                    for aliasIndex,alias in ipairs(command[1]) do
                        if aliasIndex>16 then break end
                        if alias=="dummy" or alias=="spawndummy" then
                            result[alias]=true;result.requiredPower=command[3]
                        end
                    end
                end
            end
            report.kohlRegistry=result;publish()
        end)
        if connected then
            local ok,why=pcall(function() native:FireServer("KuID") end)
            if not ok then report.kohlRegistry.status="query_error";report.kohlRegistry.error=tostring(why) end
        else report.kohlRegistry.status="observer_unavailable";report.kohlRegistry.error=why end
    else report.kohlRegistry.status="native_remote_missing" end
    local protocol=ctx and ctx.protocol
    if not ctx or ctx.initialized~=true or ctx.cancelled or (ctx.cleanup and ctx.cleanup.dead)
        or type(ctx.combat)~="table" or type(ctx.combat.request)~="function" then
        report.probe.status="client_unavailable"
    elseif type(protocol)~="table" or type(protocol.names)~="table" or type(protocol.eventIds)~="table" then
        report.probe.status="protocol_unavailable"
    else
        local folder=find(storage,protocol.names.Folder)
        local version,build=find(folder,protocol.names.Version),find(folder,protocol.names.BuildId)
        report.serverProtocol={version=read(version,"Value"),buildId=read(build,"Value"),
            clientVersion=protocol.version,clientBuildId=protocol.buildId}
        if not isA(version,"IntValue") or not isA(build,"StringValue") or version.Value~=4
            or version.Value~=protocol.version or build.Value~=protocol.buildId
            or not ctx.manifest or build.Value~=ctx.manifest.buildId then
            report.probe.status="protocol_mismatch"
        else
            local seen={}
            local statesOK,states=pcall(function() return ctx.state:all() end)
            if statesOK and type(states)=="table" then
                local count=0;for model in pairs(states) do count+=1;if count>2048 then break end;seen[model]=true end
            end
            local event=find(folder,protocol.names.Presentation)
            local connected,why=observe(event and event.OnClientEvent,function(id,data)
                if type(data)~="table" then return end
                if id==protocol.eventIds.Error and #report.serverErrors<20 then
                    report.serverErrors[#report.serverErrors+1]=fields(data,{"text","userId","character","serverTime"})
                elseif id==protocol.eventIds.State and data.userId==0 and typeof(data.character)=="Instance"
                    and not seen[data.character] and #report.newServerNPCs<20 then
                    seen[data.character]=true
                    report.newServerNPCs[#report.newServerNPCs+1]=fields(data,{"character","displayName","health","canAct","dead","revision","serverTime"})
                end
                publish()
            end)
            report.probe.presentationObserver=connected
            if not connected then report.probe.presentationObserverError=why end
            local accepted,result=pcall(ctx.combat.request,ctx.combat,"SpawnDummy")
            if accepted then
                report.probe.clientRequestAccepted=result==true
                if result~=true then report.probe.status="client_rejected" end
            else report.probe.status="client_request_error";report.probe.error=tostring(result) end
        end
    end
    publish()
    coroutine.wrap(function()
        wait(DURATION)
        if not open then return end
        report.after=snapshot(runtime())
        if report.kohlRegistry.status=="waiting" then report.kohlRegistry.status="no_reply" end
        if report.probe.status=="running" then
            if runtime()~=ctx or not player or player.Character~=character or ctx.cancelled then
                report.probe.status="context_changed"
            elseif #report.newServerNPCs>0 then report.probe.status="server_npc_observed"
            elseif #report.serverErrors>0 then report.probe.status="server_errors_observed"
            else report.probe.status="no_server_result_observed" end
        end
        disconnect();testButton.Text="Test finished"
        status.Text="Status: "..report.probe.status..". Copy report and send it in chat."
        publish()
    end)()
end
publish()
local shown,failure=pcall(function()
    gui=Instance.new("ScreenGui");gui.Name="FunCombat_DummyDiagnostics";gui.ResetOnSpawn=false
    pcall(function() gui.DisplayOrder=100001 end)
    local frame=Instance.new("Frame");frame.Name="Report";frame.Size=UDim2.new(0.94,0,0.84,0)
    frame.Position=UDim2.new(0.03,0,0.08,0);frame.BackgroundColor3=Color3.fromRGB(24,24,30);frame.Parent=gui
    local title=Instance.new("TextLabel");title.Text="Fun Combat: dummy test";title.Size=UDim2.new(1,-100,0,36)
    title.Position=UDim2.new(0,12,0,0);title.BackgroundTransparency=1;title.TextColor3=Color3.fromRGB(245,245,245)
    title.Font=Enum.Font.SourceSansBold;title.TextSize=20;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=frame
    local close=Instance.new("TextButton");close.Name="Close";close.Text="Close";close.Size=UDim2.new(0,70,0,28)
    close.Position=UDim2.new(1,-82,0,4);close.Parent=frame
    close.MouseButton1Click:Connect(function()
        stop();if environment.FunCombatDummyDiagnosticsGUI==gui then environment.FunCombatDummyDiagnosticsGUI=nil end
        if environment.FunCombatDummyDiagnosticsStop==stop then environment.FunCombatDummyDiagnosticsStop=nil end
        gui:Destroy()
    end)
    local scroll=Instance.new("ScrollingFrame");scroll.Name="Scroll";scroll.Size=UDim2.new(1,-24,1,-140)
    scroll.Position=UDim2.new(0,12,0,38);scroll.BackgroundTransparency=1;scroll.Parent=frame
    details=Instance.new("TextBox");details.Name="Details";details.ClearTextOnFocus=false;details.MultiLine=true
    details.TextWrapped=true;details.BackgroundTransparency=1;details.TextColor3=Color3.fromRGB(240,240,245)
    details.Font=Enum.Font.SourceSans;details.TextSize=15;details.TextXAlignment=Enum.TextXAlignment.Left
    details.TextYAlignment=Enum.TextYAlignment.Top;details.Parent=scroll
    resize=function(text)
        local height=40+math.ceil(#text/35)*20
        pcall(function() height=service("TextService"):GetTextSize(text,15,Enum.Font.SourceSans,
            Vector2.new(math.max(180,scroll.AbsoluteSize.X-20),1000000)).Y+24 end)
        details.Size=UDim2.new(1,-20,0,height);scroll.CanvasSize=UDim2.new(0,0,0,height)
    end
    status=Instance.new("TextLabel");status.Name="Status";status.Text="Test dummy sends one normal request. Wait 8 seconds, then Copy report."
    status.Size=UDim2.new(1,-24,0,54);status.Position=UDim2.new(0,12,1,-96);status.BackgroundTransparency=1
    status.TextWrapped=true;status.TextColor3=Color3.fromRGB(230,230,240);status.Font=Enum.Font.SourceSans;status.TextSize=15;status.Parent=frame
    testButton=Instance.new("TextButton");testButton.Name="TestDummy";testButton.Text="Test dummy"
    testButton.Size=UDim2.new(0.48,0,0,32);testButton.Position=UDim2.new(0,12,1,-38);testButton.Parent=frame
    testButton.MouseButton1Click:Connect(start)
    local copy=Instance.new("TextButton");copy.Name="Copy";copy.Text="Copy report"
    copy.Size=UDim2.new(0.48,-12,0,32);copy.Position=UDim2.new(0.5,0,1,-38);copy.Parent=frame
    copy.MouseButton1Click:Connect(function()
        if not open then return end
        local text=environment.FunCombatDummyDiagnosticsText
        local clipboard=setclipboard or toclipboard or (type(syn)=="table" and syn.write_clipboard)
        local copied,why=false,nil
        if type(clipboard)=="function" then copied,why=pcall(clipboard,text) end
        if copied then status.Text="Copied. Paste the report into chat."
        else
            details.Text=text
            pcall(function() details:CaptureFocus();details.SelectionStart=1;details.CursorPosition=#text+1 end)
            status.Text=(why and "Clipboard failed: "..tostring(why):sub(1,120)..". " or "Clipboard unavailable. ")
                .."Selected report: Ctrl+C, or long-press Copy on mobile."
        end
    end)
    local parents={};local playerGUI=find(player,"PlayerGui",true)
    if playerGUI then parents[#parents+1]=playerGUI end
    if type(gethui)=="function" then local ok,parent=pcall(gethui);if ok and parent then parents[#parents+1]=parent end end
    local core=service("CoreGui");if core then parents[#parents+1]=core end
    local mounted,lastError=false,"No available GUI container"
    for _,parent in ipairs(parents) do
        local ok,why=pcall(function() gui.Parent=parent end)
        if ok then mounted=true;break else lastError=tostring(why) end
    end
    assert(mounted,lastError)
    environment.FunCombatDummyDiagnosticsGUI=gui;publish()
end)
if not shown then
    report.uiError=tostring(failure);publish();stop()
    if gui then pcall(function() gui:Destroy() end) end
    warn("[Fun Combat Dummy Diagnostics] "..tostring(environment.FunCombatDummyDiagnosticsText))
end
return environment.FunCombatDummyDiagnosticsText
