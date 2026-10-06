-- Manually run this separate script, including after a failed loader.
-- It performs finite local reads only: no network, waits, preload, geometry,
-- replacement resources or avatar edits. The loader need not be running.
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
local function find(object,name,class)
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
local function attributes(object)
    local ok,result=pcall(function() return object:GetAttributes() end)
    if not ok then return unavailable(result) end
    local copy,count={},0
    for key,item in pairs(result) do
        if type(key)=="string" and key:sub(1,9)=="FunCombat" then
            count+=1;if count>40 then copy.truncated=true;break end
            copy[key]=value(item)
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
        if isA(child,"BodyColors") then report.bodyColors[#report.bodyColors+1]=fields(child,{"HeadColor","HeadColor3"}) end
    end
    local humanoid=find(character,"Humanoid",true)
    if humanoid then
        report.rigType=read(humanoid,"RigType")
        local ok,description=pcall(function() return humanoid:GetAppliedDescription() end)
        if ok and description then
            report.appliedDescription=fields(description,{"Head","Face","HeadColor","HeadScale","MoodAnimation","StaticFacialAnimation","UseAvatarSettings"})
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
warn("[Fun Combat Diagnostics] "..text)
return text
