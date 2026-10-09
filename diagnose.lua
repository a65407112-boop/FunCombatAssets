-- Manually run this separate script, including after a failed loader.
-- It reads a finite local snapshot and shows a selectable report with Copy.
-- No network, waits, preload, geometry or avatar edits. No live loader needed.
local MAX_NODES,MAX_LOG_SCAN,MAX_LOG_MESSAGES,MAX_TEXT=64,200,20,8192
local function unavailable(why) return {unavailable=tostring(why)} end
local function service(name)
    local ok,result=pcall(function() return game:GetService(name) end)
    return ok and result or nil,not ok and tostring(result) or nil
end
local function raw(object,key)
    return pcall(function() return object[key] end)
end
local function value(item)
    if item==nil then return "(nil)" end
    local kind=typeof(item)
    if kind=="Color3" then return {R=item.R,G=item.G,B=item.B} end
    if kind=="Content" then
        local result={}
        local ok,source=raw(item,"SourceType")
        result.sourceType=ok and tostring(source) or unavailable(source)
        local uriOK,uri=raw(item,"Uri")
        if uriOK then if uri~=nil then result.uri=tostring(uri) end else result.uriUnavailable=tostring(uri) end
        local objectOK,object=raw(item,"Object")
        if objectOK then
            if object then
                local classOK,class=raw(object,"ClassName")
                result.objectClass=classOK and tostring(class) or unavailable(class)
            end
        else result.objectUnavailable=tostring(object) end
        return result
    end
    if type(item)=="string" or type(item)=="boolean" or type(item)=="number" then return item end
    return tostring(item)
end
local function read(object,key)
    local ok,result=raw(object,key)
    if ok then return value(result) end
    return unavailable(result)
end
local function fields(object,keys)
    local result={}
    for _,key in ipairs(keys) do result[key]=read(object,key) end
    return result
end
local function children(object)
    local ok,result=pcall(function() return object:GetChildren() end)
    return ok and type(result)=="table" and result or {}
end
local objectAliases={["AllowDummys"]="aa7de37b6516",["Configuration"]="df288f6fc6ee"}
local function find(object,name,class)
    if not class then name=objectAliases[name] or name end
    if not object then return nil end
    local ok,result=pcall(function()
        if class then return object:FindFirstChildOfClass(name) end
        return object:FindFirstChild(name)
    end)
    return ok and result or nil
end
local function isA(object,class)
    local ok,result=pcall(function() return object:IsA(class) end)
    return ok and result==true
end
local attributeAliases={["0bc3bbc6f0b3"]="FunCombatFacialBridge",["0e807e2b2887"]="FunCombatMoodClipId",["1e5b028e37f8"]="FunCombatAvatarDiagnostic",["254133e9e604"]="FunCombatCreatorUserId",["279071d51dd9"]="FunCombatHeadSource",["27ee6b9f9807"]="canGetUp",["2f1cdf6338d0"]="Started",["3a3d5dad5154"]="FunCombatAdminState",["494013a6711c"]="FunCombatAdminSource",["544273c2cf5a"]="FunCombatMoodAnimation",["568c6ead6b85"]="FunCombatAdminError",["5cb617ed6e78"]="wallBounce",["63d6344b9bdc"]="Gender",["6483ceba95fb"]="attacking",["64bc57bd1b72"]="FunCombatConfiguredOwnerUserId",["688506395d60"]="FunCombatAdminConfigError",["79e1c2bfcfaf"]="funMeter",["93ad1fa1586b"]="carriedBy",["982f860c0ba2"]="FunCombatKohlAssetId",["98fcc4e831a0"]="ragdolled",["b2b56a5aa268"]="FunCombatAdminAllowed",["b3071dd09b9e"]="downed",["bf96acb14356"]="FunCombatKohlError",["caa74ea58dea"]="awakened",["ce72e2f223ef"]="iframes",["da5d59743278"]="carrying",["dd4cdc49a212"]="FunCombatKohlState",["fb455e7838f3"]="doing",["ff2009f0514f"]="FunCombatHeadAssetId"}
local function attributes(object)
    local ok,result=pcall(function() return object:GetAttributes() end)
    if not ok then return unavailable(result) end
    local copy,count={},0
    for key,item in pairs(result) do
        if attributeAliases[key] or (type(key)=="string" and key:sub(1,9)=="FunCombat") then
            count+=1;if count>40 then copy.truncated=true;break end
            copy[attributeAliases[key] or key]=value(item)
        end
    end
    return copy
end
local function walk(root,visitor)
    local queue,index,truncated={root},1,false
    while index<=#queue and index<=MAX_NODES do
        local current=queue[index];index+=1;visitor(current)
        local list=children(current)
        local count=math.min(#list,MAX_NODES-#queue)
        for i=1,count do queue[#queue+1]=list[i] end
        if count<#list then truncated=true end
    end
    return truncated
end
local function boundedText(text)
    text=tostring(text)
    if #text>MAX_TEXT then return text:sub(1,MAX_TEXT).." [truncated]" end
    return text
end
local environment=_G
if type(getgenv)=="function" then
    local ok,result=pcall(getgenv)
    if ok and type(result)=="table" then environment=result end
end
local report={creator=fields(game,{"CreatorId","CreatorType","PlaceId","GameId"}),fetchStatus={}}
pcall(function() report.atUtc=DateTime.now():ToIsoDate() end)
local players=service("Players")
local playerOK,player=raw(players,"LocalPlayer")
if not playerOK then player=nil end
local character
if player then
    report.user=fields(player,{"UserId","Name"});report.user.attributes=attributes(player)
    local ok,result=raw(player,"Character");if ok then character=result end
else report.user={missing=true} end
local references,referenceCount={},0
local function addReferences(properties)
    for _,item in pairs(properties) do
        local uri=type(item)=="string" and item or type(item)=="table" and item.uri
        if type(uri)=="string" and uri:find("://",1,true) and not references[uri] then
            referenceCount+=1
            if referenceCount<=128 then references[uri]=true else report.fetchStatusTruncated=true end
        end
    end
end
if character then
    report.character={Name=read(character,"Name"),attributes=attributes(character)}
    local mood=report.character.attributes.FunCombatMoodAnimation
    if type(mood)=="number" and mood>0 then addReferences({"rbxassetid://"..tostring(mood)}) end
    report.bodyColors={}
    for index,child in ipairs(children(character)) do
        if index>MAX_NODES then report.character.childrenTruncated=true;break end
        if isA(child,"BodyColors") then
            report.bodyColors[#report.bodyColors+1]=fields(child,{"HeadColor","HeadColor3","TorsoColor","TorsoColor3",
                "LeftArmColor","LeftArmColor3","RightArmColor","RightArmColor3","LeftLegColor","LeftLegColor3","RightLegColor","RightLegColor3"})
        end
    end
    report.bodyParts={}
    for _,name in ipairs({"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg","HumanoidRootPart"}) do
        local part=find(character,name)
        if part then
            local properties=fields(part,{"ClassName","Color","Material","Transparency","LocalTransparencyModifier"})
            if isA(part,"MeshPart") then
                for key,item in pairs(fields(part,{"MeshId","MeshContent","TextureID","TextureContent"})) do properties[key]=item end
                addReferences(properties)
            end
            report.bodyParts[name]={properties=properties}
        else report.bodyParts[name]={missing=true} end
    end
    local humanoid=find(character,"Humanoid",true)
    if humanoid then
        report.rigType=read(humanoid,"RigType")
        local ok,description=pcall(function() return humanoid:GetAppliedDescription() end)
        if ok and description then
            report.appliedDescription=fields(description,{"Head","Face","HeadColor","HeadScale","MoodAnimation","StaticFacialAnimation","UseAvatarSettings",
                "Torso","LeftArm","RightArm","LeftLeg","RightLeg","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"})
            report.appliedBodyParts={}
            for index,child in ipairs(children(description)) do
                if index>MAX_NODES then report.appliedBodyPartsTruncated=true;break end
                if isA(child,"BodyPartDescription") then
                    report.appliedBodyParts[#report.appliedBodyParts+1]=fields(child,{"Name","BodyPart","AssetId","Color","HeadShape"})
                end
            end
            pcall(function() description:Destroy() end)
        else report.appliedDescription=unavailable(description) end
    end
    local head=find(character,"Head")
    if head then
        report.head={properties=fields(head,{"ClassName","Color","Material","Transparency","TextureID","TextureContent","MeshId","MeshContent"}),
            attributes=attributes(head),faceControls=false,visuals={}}
        addReferences(report.head.properties)
        report.head.truncated=walk(head,function(item)
            if isA(item,"FaceControls") then report.head.faceControls=true end
            local keys
            if isA(item,"SurfaceAppearance") then
                keys={"Color","AlphaMode","ColorMap","ColorMapContent","NormalMap","NormalMapContent","MetalnessMap","MetalnessMapContent","RoughnessMap","RoughnessMapContent"}
            elseif isA(item,"Decal") then keys={"Texture","ColorMapContent","Color3","Transparency","Face"}
            elseif isA(item,"SpecialMesh") then keys={"MeshId","TextureId"}
            elseif item~=head and isA(item,"MeshPart") then keys={"MeshId","MeshContent","TextureID","TextureContent","Color","Material"} end
            if keys then
                local properties=fields(item,keys)
                report.head.visuals[#report.head.visuals+1]={class=read(item,"ClassName"),name=read(item,"Name"),properties=properties}
                addReferences(properties)
            end
        end)
    else report.head={missing=true} end
else report.character={missing=true};report.head={missing=true} end
local lighting,lightingError=service("Lighting")
if lighting then
    report.lighting={properties=fields(lighting,{"Ambient","OutdoorAmbient","Brightness","ClockTime","ExposureCompensation","GlobalShadows"}),colorCorrections={}}
    for index,child in ipairs(children(lighting)) do
        if index>MAX_NODES then report.lighting.truncated=true;break end
        if isA(child,"ColorCorrectionEffect") then
            report.lighting.colorCorrections[#report.lighting.colorCorrections+1]={name=read(child,"Name"),
                properties=fields(child,{"Enabled","Brightness","Contrast","Saturation","TintColor"})}
        end
    end
else report.lighting=unavailable(lightingError or "Lighting unavailable") end
local provider,providerError=service("ContentProvider")
if provider then
    for uri in pairs(references) do
        local ok,status=pcall(function() return provider:GetAssetFetchStatus(uri) end)
        report.fetchStatus[uri]=ok and tostring(status) or unavailable(status)
    end
else report.fetchStatusUnavailable=providerError end
-- Read the original KAI replicated numeric UserId:power entry; invoke no remote.
local storage=service("ReplicatedStorage")
local remote=find(storage,"b\a\n\a\n\a")
local admins=find(remote,"\admi\n")
report.kai={present=admins~=nil}
if admins then
    local ok,text=raw(admins,"Value")
    if ok and type(text)=="string" then
        local id=report.user.UserId
        local count=0
        for entry in text:sub(1,65536):gmatch("%S+") do
            count+=1;if count>2048 then report.kai.truncated=true;break end
            local userId,power=entry:match("^(%d+):([%-]?%d+%.?%d*)$")
            if userId and tonumber(userId)==id then report.kai.entry=entry;report.kai.power=tonumber(power);break end
        end
        if #text>65536 then report.kai.truncated=true end
    else report.kai.unavailable=tostring(text) end
end
local runtimeOK,runtime=raw(environment,"FunCombat_ExternalRuntime")
report.runtime={present=runtimeOK and type(runtime)=="table"}
if report.runtime.present then
    report.runtime.cancelled=read(runtime,"cancelled");report.runtime.initialized=read(runtime,"initialized")
    local ok,manifest=raw(runtime,"manifest")
    if ok and type(manifest)=="table" then report.runtime.buildId=read(manifest,"buildId") end
    local protocolOK,protocol=raw(runtime,"protocol")
    if protocolOK and type(protocol)=="table" then
        report.runtime.protocolVersion=read(protocol,"version");report.runtime.protocolBuildId=read(protocol,"buildId")
    end
    local reportsOK,messages=raw(runtime,"reports")
    if reportsOK and type(messages)=="table" then
        report.runtime.reports={};local count=0
        for message in pairs(messages) do
            count+=1;if count>MAX_LOG_MESSAGES then report.runtime.reportsTruncated=true;break end
            report.runtime.reports[#report.runtime.reports+1]=boundedText(message)
        end
    end
end
-- Read the replicated switch and character conditions. This does not dispatch
-- a command or certify the unseen server-side handler/cooldown/dummy limits.
local world=service("Workspace")
local configuration=find(world,"Configuration")
local dummyFlag=find(configuration,"AllowDummys")
report.dummy={configurationPresent=configuration~=nil,
    allowDummys=dummyFlag and fields(dummyFlag,{"ClassName","Value"}) or {missing=true},
    note="Local replicated snapshot only; command delivery and server-side rejection are not confirmed."}
local dummyHumanoid=find(character,"Humanoid",true)
report.dummy.humanoid=dummyHumanoid and fields(dummyHumanoid,{"Health","PlatformStand","WalkSpeed","JumpPower"}) or {missing=true}
local dummyRoot=find(character,"HumanoidRootPart")
if dummyRoot then report.dummy.rootAnchored=read(dummyRoot,"Anchored")
else report.dummy.rootAnchored={missing=true} end
if report.runtime.present then
    local ok,stateModule=raw(runtime,"state")
    if ok and type(stateModule)=="table" and type(stateModule.localState)=="function" then
        local stateOK,state=pcall(stateModule.localState,stateModule)
        if stateOK and type(state)=="table" then
            report.dummy.localState=fields(state,{"health","downed","ragdolled","busy","canAct","carrying","carriedBy"})
            report.dummy.stateCharacterMatches=state.character==character
        elseif not stateOK then report.dummy.localState=unavailable(state)
        else report.dummy.localState={missing=true} end
    else report.dummy.localState={missing=true} end
end
local guiOK,gui=raw(environment,"FunCombat_ExternalRuntime_ErrorGUI")
if guiOK and gui then
    walk(gui,function(item)
        if not report.failureWindow and isA(item,"TextBox") and read(item,"Name")=="Details" then
            local ok,text=raw(item,"Text");if ok then report.failureWindow=boundedText(text) end
        end
    end)
end
local logs,logError=service("LogService")
if logs then
    local ok,history=pcall(function() return logs:GetLogHistory() end)
    if ok and type(history)=="table" then
        report.loadMessages={}
        for index=#history,math.max(1,#history-MAX_LOG_SCAN+1),-1 do
            local entry=history[index]
            local text=type(entry)=="table" and tostring(entry.message or "") or ""
            local lower=text:lower()
            local relevant=tostring(type(entry)=="table" and entry.messageType or ""):find("MessageError",1,true)
                or lower:find("fun combat",1,true) or lower:find("funcombat",1,true)
                or lower:find("kohl",1,true)
                or lower:find("failed to load",1,true) or lower:find("unable to load",1,true)
                or lower:find("rbxasset",1,true) or lower:find("contentprovider",1,true)
            if relevant and not lower:find("[fun combat diagnostics]",1,true) then
                report.loadMessages[#report.loadMessages+1]={message=boundedText(text),messageType=value(entry.messageType),timestamp=value(entry.timestamp)}
                if #report.loadMessages>=MAX_LOG_MESSAGES then report.loadMessagesTruncated=true;break end
            end
        end
        if #history>MAX_LOG_SCAN then report.logHistoryScanTruncated=true end
    else report.loadMessagesUnavailable=tostring(history) end
else report.loadMessagesUnavailable=logError end
report.note="Fetch status does not confirm rendering or processed PBR pack availability. This is a local snapshot; the website avatar may change after joining. Missing or protected fields are not evidence of a failed download. Recent client errors may be unrelated."
local http,httpError=service("HttpService")
local ok,text=pcall(function() assert(http,httpError);return http:JSONEncode(report) end)
if not ok then
    local function format(item,depth)
        if type(item)~="table" then return tostring(item) end
        if depth>10 then return "[depth limit]" end
        local keys={};for key in pairs(item) do keys[#keys+1]=key end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local parts={};for _,key in ipairs(keys) do parts[#parts+1]=tostring(key).."="..format(item[key],depth+1) end
        return "{"..table.concat(parts,", ").."}"
    end
    text="JSON unavailable: "..tostring(text).."; "..format(report,0)
end
pcall(function() environment.FunCombatDiagnostics=report;environment.FunCombatDiagnosticsText=text end)
local gui
local shown,uiError=pcall(function()
    local old=environment.FunCombatDiagnosticsGUI
    if old then pcall(function() old:Destroy() end) end
    environment.FunCombatDiagnosticsGUI=nil
    gui=Instance.new("ScreenGui");gui.Name="FunCombat_Diagnostics";gui.ResetOnSpawn=false
    pcall(function() gui.DisplayOrder=100000 end)
    local frame=Instance.new("Frame");frame.Name="Report";frame.Size=UDim2.new(0.9,0,0.8,0)
    frame.Position=UDim2.new(0.05,0,0.1,0);frame.BackgroundColor3=Color3.fromRGB(24,24,30)
    frame.BorderSizePixel=0;frame.Parent=gui
    local title=Instance.new("TextLabel");title.Name="Title";title.Text="Fun Combat diagnostics"
    title.Size=UDim2.new(1,-100,0,40);title.Position=UDim2.new(0,12,0,0);title.BackgroundTransparency=1
    title.TextColor3=Color3.fromRGB(245,245,245);title.Font=Enum.Font.SourceSansBold;title.TextSize=20
    title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=frame
    local close=Instance.new("TextButton");close.Name="Close";close.Text="Close";close.Size=UDim2.new(0,72,0,28)
    close.Position=UDim2.new(1,-84,0,6);close.Parent=frame
    close.MouseButton1Click:Connect(function()
        if environment.FunCombatDiagnosticsGUI==gui then environment.FunCombatDiagnosticsGUI=nil end
        gui:Destroy()
    end)
    local scroll=Instance.new("ScrollingFrame");scroll.Name="Scroll";scroll.Size=UDim2.new(1,-24,1,-116)
    scroll.Position=UDim2.new(0,12,0,42);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Parent=frame
    local details=Instance.new("TextBox");details.Name="Details";details.Text=text;details.ClearTextOnFocus=false
    details.MultiLine=true;details.TextWrapped=true;details.BackgroundTransparency=1
    details.TextColor3=Color3.fromRGB(240,240,245);details.Font=Enum.Font.SourceSans;details.TextSize=16
    details.TextXAlignment=Enum.TextXAlignment.Left;details.TextYAlignment=Enum.TextYAlignment.Top;details.Parent=scroll
    local function resize()
        local height=40+math.ceil(#text/35)*20
        pcall(function()
            height=game:GetService("TextService"):GetTextSize(text,16,Enum.Font.SourceSans,
                Vector2.new(math.max(180,scroll.AbsoluteSize.X-20),1000000)).Y+24
        end)
        details.Size=UDim2.new(1,-20,0,height);scroll.CanvasSize=UDim2.new(0,0,0,height)
    end
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    local status=Instance.new("TextLabel");status.Name="Status";status.Text="Copy the report and send it in chat."
    status.Size=UDim2.new(1,-190,0,62);status.Position=UDim2.new(0,180,1,-68);status.BackgroundTransparency=1
    status.TextWrapped=true;status.TextColor3=Color3.fromRGB(215,215,225);status.Font=Enum.Font.SourceSans
    status.TextSize=15;status.TextXAlignment=Enum.TextXAlignment.Left;status.Parent=frame
    local copy=Instance.new("TextButton");copy.Name="Copy";copy.Text="Copy report";copy.Size=UDim2.new(0,156,0,34)
    copy.Position=UDim2.new(0,12,1,-56);copy.Font=Enum.Font.SourceSansBold;copy.TextSize=18;copy.Parent=frame
    copy.MouseButton1Click:Connect(function()
        if environment.FunCombatDiagnosticsGUI~=gui then return end
        local clipboard=setclipboard
        if type(clipboard)~="function" then clipboard=toclipboard end
        if type(clipboard)~="function" and type(syn)=="table" then clipboard=syn.write_clipboard end
        local copied,why=false,nil
        if type(clipboard)=="function" then copied,why=pcall(clipboard,text) end
        if copied then
            status.Text="Copied. Paste the report into chat.";copy.Text="Copy again"
        else
            details.Text=text
            local selected=pcall(function()
                details:CaptureFocus();details.SelectionStart=1;details.CursorPosition=#text+1
            end)
            local hint=selected and "Selected report: Ctrl+C, or long-press Copy on mobile."
                or "Click the report, then Ctrl+A and Ctrl+C (long-press Copy on mobile)."
            status.Text=why and "Clipboard failed: "..tostring(why):sub(1,180)..". "..hint or "Clipboard unavailable. "..hint
        end
    end)
    local parents={}
    local playerGui=find(player,"PlayerGui",true)
    if playerGui then parents[#parents+1]=playerGui end
    if type(gethui)=="function" then
        local ok,parent=pcall(gethui);if ok and parent then parents[#parents+1]=parent end
    end
    local core=service("CoreGui");if core then parents[#parents+1]=core end
    local lastError="No permitted GUI container is available"
    local mounted=false
    for _,parent in ipairs(parents) do
        local ok,why=pcall(function() gui.Parent=parent end)
        if ok then mounted=true;break else lastError=tostring(why) end
    end
    assert(mounted,lastError)
    resize();environment.FunCombatDiagnosticsGUI=gui
end)
if not shown and gui then pcall(function() gui:Destroy() end) end
pcall(function() environment.FunCombatDiagnosticsUIError=not shown and tostring(uiError) or nil end)
warn("[Fun Combat Diagnostics] "..text..(not shown and "\nDiagnostic window unavailable: "..tostring(uiError) or ""))
return text
