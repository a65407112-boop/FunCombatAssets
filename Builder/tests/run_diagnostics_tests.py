"""Run the standalone diagnostic chunk with Roblox APIs doubled.

These tests verify finite local reads, exact diagnostics and appearance
preservation. They make no engine/CDN/rendering claim.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
header = r'''
local services,environment,warnings,reads,fetches,blockedAppearanceWrites
local setclipboard,gethui,clipboardText
local function signal()
    local callbacks={}
    return {Connect=function(_,callback) callbacks[#callbacks+1]=callback;return {Disconnect=function() end} end,
        Fire=function(_,...) for _,callback in ipairs(callbacks) do callback(...) end end}
end
local function typeof(value) return type(value)=='table' and value.kind or type(value) end
local function getgenv() return environment end
local function warn(message) warnings[#warnings+1]=message end
local function tick() return 100 end
local function wait() error('Standalone diagnostics must not wait') end
local task={wait=wait,spawn=function() error('Diagnostics started background work') end,delay=wait}
local function request() error('Diagnostics requested network content') end
local function require() error('Diagnostics required an external module') end
local DateTime={now=function() return {ToIsoDate=function() return '2026-10-06T15:00:00Z' end} end}
local methods={}
local function node(class,name)
    local props={ClassName=class,Name=name or class,children={},attributes={},denied={}}
    local object={kind='Instance',props=props}
    return setmetatable(object,{__index=function(_,key)
        reads[#reads+1]=key
        assert(key~='Size' and key~='CFrame' and key~='Position' and key~='MeshSize','Geometry was inspected')
        if props.denied[key] then error(props.denied[key]) end
        return methods[key] or props[key]
    end,__newindex=function(_,key,value)
        if props.readOnly then blockedAppearanceWrites+=1 end
        assert(not props.readOnly,'Diagnostic wrote the actual appearance property '..key)
        if props.isDiagnosticUI and key=='Parent' then
            if props.Parent and props.Parent.children then
                for i=#props.Parent.children,1,-1 do if props.Parent.children[i]==object then table.remove(props.Parent.children,i) end end
            end
            if value then
                assert(not value.props.denyUI,'UI parenting denied')
                value.children[#value.children+1]=object
            end
        end
        props[key]=value
    end})
end
function methods:IsA(class) return self.ClassName==class or class=='Instance' end
function methods:GetChildren() return self.children end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(self.children) do
        if child.Name==name then return child end
        if recursive then local match=child:FindFirstChild(name,true);if match then return match end end
    end
end
function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.children) do if child:IsA(class) then return child end end end
function methods:GetAttributes() return self.attributes end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy()
    assert(self.ClassName=='HumanoidDescription' or self.props.isDiagnosticUI,'Diagnostic destroyed a real avatar instance')
    if self.props.isDiagnosticUI then for _,child in ipairs(self:GetChildren()) do child:Destroy() end;self.Parent=nil end
    self.props.destroyed=true
end
function methods:CaptureFocus() assert(self.ClassName=='TextBox');self.props.focused=true end
function methods:GetPropertyChangedSignal(name)
    self.props.changes=self.props.changes or {};self.props.changes[name]=self.props.changes[name] or signal();return self.props.changes[name]
end
local Instance={new=function(class)
    local object=node(class);object.props.isDiagnosticUI=true
    if class=='TextButton' then object.MouseButton1Click=signal() end
    if class=='ScrollingFrame' then object.AbsoluteSize={X=800,Y=400} end
    return object
end}
local UDim2={new=function(...) return {...} end}
local Color3={fromRGB=function(...) return {...} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Enum={Font={SourceSans='SourceSans',SourceSansBold='SourceSansBold',Code='Code'},
    TextXAlignment={Left='Left'},TextYAlignment={Top='Top'}}
local function append(parent,child) parent.children[#parent.children+1]=child;child.Parent=parent;return child end
local function color(value) return {kind='Color3',R=value,G=value,B=value} end
local function content(uri,object)
    return {kind='Content',SourceType=object and 'Enum.ContentSourceType.Object' or 'Enum.ContentSourceType.Uri',Uri=uri,Object=object}
end
local game=setmetatable({GetService=function(_,name)
    local service=services[name];assert(service,'Service denied: '..name);return service
end,HttpGet=request},{__index=function(_,key)
    if key=='CreatorId' then return 998877 end
    if key=='CreatorType' then return 'Enum.CreatorType.User' end
    if key=='PlaceId' then return 223344 end
    if key=='GameId' then return 556677 end
    error('Unavailable DataModel property '..key)
end})
local function validate(value,seen)
    local kind=type(value)
    assert(kind=='nil' or kind=='boolean' or kind=='number' or kind=='string' or kind=='table','JSON contains unsupported userdata')
    if kind=='table' then
        assert(not value.kind,'JSON contains an unsanitized engine object')
        seen=seen or {};assert(not seen[value],'JSON contains a cycle');seen[value]=true
        for _,child in pairs(value) do validate(child,seen) end
        seen[value]=nil
    end
end
local function fixture(empty)
    environment={};warnings={};reads={};fetches={};blockedAppearanceWrites=0;setclipboard=nil;gethui=nil;clipboardText=nil
    local player=node('Player','ActualAccount');player.UserId=11556197791;player.Parent=true
    player.attributes={FunCombatAdminAllowed=true,FunCombatAdminSource='configuredOwner',FunCombatCreatorUserId=998877,
        FunCombatConfiguredOwnerUserId=11556197791,FunCombatAdminState='ready',UnrelatedAttribute='omit'}
    local character=node('Model','ActualCharacter');character.Parent=true;player.Character=character
    character.attributes={FunCombatHeadAssetId=89515250410521,FunCombatMoodAnimation=14618207727,
        FunCombatAvatarDiagnostic='Original dynamic head timeout: rbxassetid://89515250410521'}
    local description=node('HumanoidDescription');description.Head=89515250410521;description.Face=0
    description.HeadColor=color(248/255);description.MoodAnimation=14618207727
    local humanoid=append(character,node('Humanoid'));humanoid.RigType='Enum.HumanoidRigType.R6'
    humanoid.GetAppliedDescription=function() return description end
    local body=append(character,node('BodyColors'));body.HeadColor='Institutional white';body.HeadColor3=color(248/255)
    local head
    if not empty then
        head=append(character,node('MeshPart','Head'));head.Color=color(248/255);head.Material='Enum.Material.Plastic'
        head.TextureID='rbxassetid://7001';head.MeshId='rbxassetid://6001';head.Transparency=0
        head.TextureContent=content('rbxassetid://7001');head.MeshContent=content('rbxassetid://6001')
        append(head,node('FaceControls'))
    end
    local rs=node('ReplicatedStorage');local remote=append(rs,node('RemoteEvent','b\a\n\a\n\a'))
    local admins=append(remote,node('StringValue','\admi\n'));admins.Value=' ActualAccount:7 115561977910:6 998877:6 11556197791:5'
    services={Players={LocalPlayer=player},ReplicatedStorage=rs,
        ContentProvider={GetAssetFetchStatus=function(_,uri) fetches[#fetches+1]=uri;return uri=='rbxassetid://7001' and 'Enum.AssetFetchStatus.Failure' or 'Enum.AssetFetchStatus.Success' end,
            PreloadAsync=request},
        LogService={GetLogHistory=function() return {} end},
        HttpService={JSONEncode=function(_,report) validate(report);return '[mock JSON snapshot]' end}}
    return player,character,head,description,admins
end
local function run()
    local result=runDiagnostics()
    assert(type(result)=='string' and #warnings==1,'Standalone chunk did not print and return its report')
    assert(blockedAppearanceWrites==0,'A protected pcall hid an attempted appearance edit')
    for _,key in ipairs(reads) do
        assert(key~='Size' and key~='CFrame' and key~='Position' and key~='MeshSize','A protected pcall hid a geometry read')
    end
    return environment.FunCombatDiagnostics
end
local function uiFixture()
    local player,character,head=fixture()
    local parent=append(player,node('PlayerGui'))
    services.TextService={GetTextSize=function() return {X=700,Y=1200} end}
    return player,character,head,parent
end
local function window()
    local gui=environment.FunCombatDiagnosticsGUI
    assert(gui and gui.Parent,'Diagnostic did not show a window without console access')
    local details=assert(gui:FindFirstChild('Details',true),'Report is not selectable')
    local copy=assert(gui:FindFirstChild('Copy',true),'Copy report button is missing')
    local status=assert(gui:FindFirstChild('Status',true),'Copy result is not visible')
    return gui,details,copy,status
end
local function has(list,text) for _,entry in ipairs(list or {}) do if tostring(entry.message or entry):find(text,1,true) then return true end end end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Diagnostics: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
'''
checks = r'''
check('all original body colors and applied colors remain distinct in the report',function()
    local _,character,_,description=fixture();local body=character:FindFirstChildOfClass('BodyColors')
    for index,prefix in ipairs({'Head','Torso','LeftArm','RightArm','LeftLeg','RightLeg'}) do
        body[prefix..'Color3']=color(index/10);description[prefix..'Color']=color(index/10)
    end
    body.props.readOnly=true
    local report=run()
    assert(report.bodyColors[1].TorsoColor3 and report.bodyColors[1].TorsoColor3.R==0.2,'Actual torso BodyColors were omitted')
    for index,prefix in ipairs({'Head','Torso','LeftArm','RightArm','LeftLeg','RightLeg'}) do
        assert(report.bodyColors[1][prefix..'Color3'].R==index/10,'A limb color was replaced with the head color')
        assert(report.appliedDescription[prefix..'Color'].R==index/10,'Applied description body color was omitted')
    end
end)
check('black body parts and local visibility are recorded without appearance edits or geometry reads',function()
    local _,character=fixture()
    for index,name in ipairs({'Torso','Left Arm','Right Arm','Left Leg','Right Leg','HumanoidRootPart'}) do
        local part=append(character,node('Part',name));part.Color=color(index==1 and 0 or index/10)
        part.Transparency=index==6 and 1 or 0;part.LocalTransparencyModifier=0.25;part.Material='Enum.Material.Plastic'
        part.props.readOnly=true
    end
    local report=run()
    assert(report.bodyParts and report.bodyParts.Torso.properties.Color.R==0,'Actual black torso color was not captured')
    assert(report.bodyParts['Left Arm'].properties.Color.R==0.2 and report.bodyParts['Right Leg'].properties.LocalTransparencyModifier==0.25,
        'Distinct limb appearance or local visibility was not captured')
    assert(report.bodyParts.HumanoidRootPart.properties.Transparency==1,'The root was mistaken for a visible limb')
    assert(report.bodyParts.Head.properties.Color.R==248/255,'The working head appearance was altered')
end)
check('structured applied body metadata preserves color and explicit asset IDs in a bounded snapshot',function()
    local _,_,_,description=fixture()
    local part=append(description,node('BodyPartDescription','ActualTorso'))
    part.BodyPart='Enum.BodyPart.Torso';part.Color=color(0);part.AssetId=0;part.HeadShape='';part.props.readOnly=true
    for index=1,100 do append(description,node('Folder','Unrelated'..index)) end
    local report=run()
    assert(report.appliedBodyParts and #report.appliedBodyParts==1 and report.appliedBodyParts[1].Color.R==0,
        'Structured body color was omitted or replaced')
    assert(report.appliedBodyParts[1].AssetId==0 and report.appliedBodyPartsTruncated,'Zero body ID or truncation was misreported')
end)
check('current lighting and color correction are reported without changing them',function()
    fixture();local lighting=node('Lighting');lighting.Ambient=color(0);lighting.OutdoorAmbient=color(0.5)
    lighting.Brightness=2;lighting.ExposureCompensation=-1;lighting.ClockTime=18;services.Lighting=lighting
    local correction=append(lighting,node('ColorCorrectionEffect','ActualCorrection'))
    correction.Enabled=true;correction.TintColor=color(0.1);correction.Brightness=-0.2;correction.Saturation=0.4;correction.Contrast=0.3
    lighting.props.readOnly=true;correction.props.readOnly=true
    local report=run()
    assert(report.lighting and report.lighting.properties.Ambient.R==0 and report.lighting.properties.ExposureCompensation==-1,
        'The actual lighting values were omitted')
    assert(#report.lighting.colorCorrections==1 and report.lighting.colorCorrections[1].properties.TintColor.R==0.1,
        'Active color correction was omitted')
    warnings={};services.Lighting=nil;report=run();assert(report.lighting.unavailable,'Denied lighting API was treated as a known state')
end)
check('replicated dummy toggle reports true and false without enabling either',function()
    for _,enabled in ipairs({true,false}) do
        fixture();local world=node('Workspace');services.Workspace=world
        local config=append(world,node('Configuration','Configuration'))
        local flag=append(config,node('BoolValue','AllowDummys'));flag.Value=enabled;flag.props.readOnly=true
        local report=run()
        assert(report.dummy and report.dummy.allowDummys and report.dummy.allowDummys.Value==enabled,
            'Actual replicated AllowDummys is absent or misreported')
        assert(report.dummy.allowDummys.ClassName=='BoolValue' and flag.Value==enabled,'Diagnostic changed or invented the toggle')
    end
end)
check('missing dummy configuration remains explicitly missing',function()
    fixture();services.Workspace=node('Workspace');local report=run()
    assert(report.dummy and report.dummy.allowDummys.missing==true,'Absent toggle was assumed enabled or disabled')
end)
check('an unanchored dummy requester is reported as false rather than missing',function()
    local _,character=fixture();local root=append(character,node('Part','HumanoidRootPart'));root.Anchored=false;root.props.readOnly=true
    local report=run()
    assert(report.dummy and report.dummy.rootAnchored==false,'A false Anchored value was mistaken for a missing root')
end)
check('native Kohl custom command failures are retained even when printed as output',function()
    fixture();services.LogService.GetLogHistory=function() return {{message="Kohl's Admin Infinite Custom Command Error: command callback failed",messageType='Enum.MessageType.MessageOutput',timestamp=123}} end
    local report=run()
    assert(has(report.loadMessages,'Custom Command Error'),'Native Kohl command load failure was filtered out')
end)
check('dummy local character conditions are copied without calling server or inspecting geometry',function()
    local _,character=fixture();local humanoid=character:FindFirstChildOfClass('Humanoid')
    humanoid.Health=100;humanoid.PlatformStand=false
    local root=append(character,node('Part','HumanoidRootPart'));root.Anchored=true;root.props.readOnly=true
    local state={character=character,health=100,downed=false,busy=true,ragdolled=false,canAct=false,carrying='local reference'}
    environment.FunCombat_ExternalRuntime={initialized=true,cancelled=false,state={localState=function() return state end}}
    local report=run()
    assert(report.dummy and report.dummy.rootAnchored==true and report.dummy.humanoid.Health==100,'Live movement/health conditions were lost')
    assert(report.dummy.localState.busy==true and report.dummy.localState.canAct==false and report.dummy.stateCharacterMatches==true,
        'Blocking local state or character identity was not captured')
    assert(root.Anchored and state.busy,'Read-only probe changed gameplay state')
end)
check('actual user, creator and owner attrs use the native numeric KAI entry',function()
    fixture();local report=run()
    assert(report.user.UserId==11556197791 and report.creator.CreatorId==998877,'Actual identity was not captured')
    assert(report.user.attributes.FunCombatConfiguredOwnerUserId==11556197791,'Configured owner attr missing')
    assert(report.user.attributes.UnrelatedAttribute==nil,'Unrelated player attributes were dumped')
    assert(report.kai.entry=='11556197791:5' and report.kai.power==5,'Username or a different numeric ID was confused with the native entry')
    assert(report.character.attributes.FunCombatHeadAssetId==89515250410521 and report.character.attributes.FunCombatMoodAnimation==14618207727,'Original head/mood sources missing')
end)
check('fatal cleanup does not hide the exact failure window and native load messages',function()
    fixture();local gui=node('ScreenGui');local panel=append(gui,node('Frame','Error'))
    local text=append(panel,node('TextBox','Details'));text.Text='Original resource warm-up failed: costumes/TorsoRig WeldConstraint.Part0Internal not valid member'
    environment.FunCombat_ExternalRuntime_ErrorGUI=gui
    services.LogService.GetLogHistory=function() return {{message='Unable to load Texture rbxassetid://7001: denied',messageType='Enum.MessageType.MessageError',timestamp=123},
        {message='[Fun Combat] retained native warning',messageType='Enum.MessageType.MessageWarning',timestamp=124},
        {message='Processed image content inaccessible',messageType='Enum.MessageType.MessageError',timestamp=125}} end
    local report=run()
    assert(report.runtime.present==false and report.failureWindow:find('Part0Internal',1,true),'Standalone capture required the destroyed loader context')
    assert(has(report.loadMessages,'7001: denied') and has(report.loadMessages,'retained native warning'),'Exact available errors disappeared')
    assert(has(report.loadMessages,'Processed image content inaccessible'),'An engine error was hidden by guessed asset-message wording')
end)
check('both PBR APIs are read safely and preserve raw Content source provenance',function()
    local _,_,head=fixture();local pbr=append(head,node('SurfaceAppearance','OriginalPBR'))
    pbr.Color=color(0);pbr.AlphaMode='Enum.AlphaMode.Overlay';pbr.denied.ColorMap='ColorMap access denied'
    pbr.ColorMapContent=content('rbxassetid://8001');pbr.NormalMap='rbxassetid://8002';pbr.denied.NormalMapContent='Unknown property'
    local image=node('EditableImage','OriginalEditableImage');pbr.RoughnessMapContent=content(nil,image)
    pbr.props.readOnly=true;head.props.readOnly=true
    local report=run();local entry=report.head.visuals[1]
    assert(entry.class=='SurfaceAppearance' and entry.properties.ColorMap.unavailable:find('access denied',1,true),'Restricted legacy API was treated as usable or fatal')
    assert(entry.properties.ColorMapContent.uri=='rbxassetid://8001' and entry.properties.NormalMap=='rbxassetid://8002','Available modern/legacy PBR references were lost')
    assert(entry.properties.NormalMapContent.unavailable and entry.properties.RoughnessMapContent.objectClass=='EditableImage','Unavailable Content or object provenance was invented')
    assert(report.fetchStatus['rbxassetid://8001']=='Enum.AssetFetchStatus.Success' and report.note:find('does not confirm rendering',1,true),'Raw PBR URI status was certified as rendering')
end)
check('actual white and black appearance values survive unchanged',function()
    for _,value in ipairs({248/255,0}) do
        local _,_,head,description=fixture();head.Color=color(value);head.props.readOnly=true
        local original=head.Color;local report=run()
        assert(report.head.properties.Color.R==value and head.Color==original and head.TextureID=='rbxassetid://7001','Probe repaired or obscured the actual head color')
        assert(report.head.faceControls==true and report.head.properties.MeshId=='rbxassetid://6001','Actual head capability or reference missing')
        assert(report.fetchStatus['rbxassetid://7001']=='Enum.AssetFetchStatus.Failure','Actual hosted failure status missing')
        assert(description.props.destroyed,'Temporary local description metadata was retained')
    end
end)
check('an absent character or absent Head returns immediately without substitutes',function()
    local player=fixture();player.Character=nil;local report=run();assert(report.character.missing and #fetches==0,'Missing character caused an invented request')
    fixture(true);report=run();assert(report.head.missing and #fetches==1 and fetches[1]=='rbxassetid://14618207727',
        'Missing Head waited or queried invented resources instead of only the real replicated mood')
end)
check('denied services, legacy fields and applied descriptions remain diagnostic',function()
    local _,character,head=fixture();services.ContentProvider=nil;services.LogService=nil
    services.HttpService.JSONEncode=function() error('JSON unavailable') end
    head.denied.TextureID='TextureID denied';head.denied.MeshContent='MeshContent unavailable'
    character:FindFirstChildOfClass('Humanoid').GetAppliedDescription=function() error('Applied description unavailable') end
    local report=run()
    assert(report.head.properties.TextureID.unavailable and report.head.properties.MeshContent.unavailable,'Property denial aborted the snapshot')
    assert(report.appliedDescription.unavailable and report.loadMessagesUnavailable and report.fetchStatusUnavailable,'Unavailable APIs were silently treated as success')
    assert(type(environment.FunCombatDiagnosticsText)=='string' and environment.FunCombatDiagnosticsText:find('JSON unavailable',1,true),'JSON failure lost the printable snapshot')
end)
check('available cancelled runtime reports are read without invoking its modules',function()
    fixture();environment.FunCombat_ExternalRuntime={cancelled=true,initialized=false,manifest={buildId='actual-build'},
        protocol={version=4,buildId='server-build'},modules={avatar_content={},preload={}},reports={['Exact warm-up issue']=true},
        destroy=function() error('Probe destroyed runtime') end,state={localState=function() error('Probe invoked runtime state') end}}
    local report=run()
    assert(report.runtime.present and report.runtime.cancelled and report.runtime.initialized==false and report.runtime.buildId=='actual-build','Available diagnostic runtime state lost')
    assert(report.runtime.protocolVersion==4 and report.runtime.protocolBuildId=='server-build','Available protocol diagnostics missing')
    assert(has(report.runtime.reports,'Exact warm-up issue') and environment.FunCombat_ExternalRuntime.cancelled,'Probe changed existing runtime state')
end)
check('classic decals are captured and head tree/log reads have finite caps',function()
    local _,_,head=fixture();local face=append(head,node('Decal','face'));face.Texture='rbxassetid://9001';face.Color3=color(1)
    face.denied.ColorMapContent='Modern API unavailable';face.Transparency=0
    for i=1,200 do append(head,node('Attachment','BoneMetadata'..i)) end
    services.LogService.GetLogHistory=function() local list={};for i=1,700 do list[i]={message='Unable to load texture '..i,messageType='Enum.MessageType.MessageWarning',timestamp=i} end;return list end
    local report=run();local entry=report.head.visuals[1]
    assert(entry.class=='Decal' and entry.properties.Texture=='rbxassetid://9001','Classic face was lost')
    assert(report.head.truncated and #report.loadMessages<=20 and has(report.loadMessages,'700'),'Bounded reads lost newest errors or inspected the whole history/tree')
    assert(#fetches<=16,'Finite head data multiplied hosted status requests')
end)
check('report opens without console and Copy sends the exact snapshot to clipboard',function()
    local _,_,head,parent=uiFixture();head.props.readOnly=true
    setclipboard=function(text) clipboardText=text end
    run();local gui,details,copy,status=window()
    assert(gui.Parent==parent and details.Text==environment.FunCombatDiagnosticsText,'Window displayed a different snapshot')
    details.Text='Edited display only';copy.MouseButton1Click:Fire()
    assert(clipboardText==environment.FunCombatDiagnosticsText,'Copy button copied altered or incomplete data')
    assert(status.Text:find('Copied',1,true),'Successful copying was not confirmed on screen')
end)
check('unsupported clipboard keeps Copy and selects the complete report for manual copying',function()
    uiFixture();run();local _,details,copy,status=window();copy.MouseButton1Click:Fire()
    assert(details.props.focused and details.SelectionStart==1 and details.CursorPosition==#environment.FunCombatDiagnosticsText+1,'Manual fallback did not select the full report')
    assert(status.Text:find('Ctrl',1,true) and not status.Text:find('Copied',1,true),'Missing clipboard was falsely reported as copied')
end)
check('clipboard rejection is visible and preserves manual copying',function()
    uiFixture();setclipboard=function() error('clipboard denied by executor') end
    run();local _,details,copy,status=window();copy.MouseButton1Click:Fire()
    assert(status.Text:find('clipboard denied',1,true) and details.props.focused,'Clipboard failure lost the exact error or manual fallback')
end)
check('rerun replaces only its previous window and Close releases the diagnostic GUI',function()
    local _,character,head=uiFixture();run();local old=window();warnings={};run();local gui=window()
    assert(old.props.destroyed and gui~=old and not head.props.destroyed,'Rerun leaked a window or touched the avatar')
    local close=assert(gui:FindFirstChild('Close',true));close.MouseButton1Click:Fire()
    assert(gui.props.destroyed and environment.FunCombatDiagnosticsGUI==nil and character.Parent,'Close damaged gameplay or retained its GUI')
end)
check('absent PlayerGui uses an available executor GUI container',function()
    fixture();local parent=node('Folder','ExecutorUI');gethui=function() return parent end
    run();local gui=window();assert(gui.Parent==parent,'Standalone UI required a live loader or console')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Standalone diagnostic regression scenarios passed: '..total)
'''
# RED means the old absent script returns no diagnostic, not a Python read error.
path = ROOT / 'diagnose.lua'
source = path.read_text() if path.exists() else 'return nil'
script = 'local runDiagnostics\n' + header + '\nrunDiagnostics=function()\n' + source + '\nend\n' + checks
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    test_path = Path(temporary) / 'diagnostics.luau'
    test_path.write_text(script)
    subprocess.run([str(Path(args.luau).resolve()), str(test_path)], check=True, timeout=15)
