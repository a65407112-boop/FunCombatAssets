"""Exercise the manual texture comparison, not Roblox rendering.

Breaks caught: applying a different face, altered transparent pixels, avatar
mutation, leaked native resources after failure/timeout, and unusable copy UI.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Builder'))
from build import lua

parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
document_path = ROOT / 'diagnostics/head_texture_130652123696339.json'
document = json.loads(document_path.read_text()) if document_path.exists() else {}
header = r'''
local environment,services,requests,createdImages,createdSurfaces,clock,pending,clipboardText,runHeadTest,onSpawnReturn
local originalBuffer=buffer
local originalContent={fromObject=function(object) return {Object=object} end}
local buffer,Content=originalBuffer,originalContent
local function getgenv() return environment end
local function warn() end
local function tick() return clock end
local task={spawn=function(fn)
        local co=coroutine.create(fn);assert(coroutine.resume(co))
        if onSpawnReturn then local callback=onSpawnReturn;onSpawnReturn=nil;callback() end
    end,
    wait=function() clock+=0.1 end}
local function setclipboard(text) clipboardText=text end
local function signal()
    local list={}
    return {Connect=function(_,callback)
        local record={callback=callback,alive=true};list[#list+1]=record
        return {Disconnect=function() record.alive=false end}
    end,Fire=function(_,...) for _,r in ipairs(list) do if r.alive then r.callback(...) end end end}
end
local methods={}
local function node(class,name)
    local data={ClassName=class,Name=name or class,children={},attributes={},AncestryChanged=signal()}
    local object={data=data}
    return setmetatable(object,{__index=function(_,key)
        assert(key~='Size' or class~='MeshPart','Geometry was inspected')
        assert(key~='CFrame' and key~='MeshSize' and key~='Position' or class~='MeshPart','Geometry was inspected')
        return methods[key] or data[key]
    end,__newindex=function(_,key,value)
        assert(not data.avatar,'Test mutated the real avatar: '..key)
        if key=='Parent' then
            if data.Parent then for i=#data.Parent.children,1,-1 do if data.Parent.children[i]==object then table.remove(data.Parent.children,i) end end end
            if value then value.children[#value.children+1]=object end
        end
        data[key]=value
    end})
end
function methods:IsA(class) return self.ClassName==class end
function methods:FindFirstChild(name)
    for _,child in ipairs(self.children) do if child.Name==name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self.children) do if child.ClassName==class then return child end end
end
function methods:GetChildren() return self.children end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy()
    assert(not self.data.avatar,'Test destroyed an original instance')
    for i=#self.children,1,-1 do self.children[i]:Destroy() end
    self.Parent=nil;self.data.destroyed=true
end
function methods:GetPropertyChangedSignal(name)
    self.data.changes=self.data.changes or {}
    self.data.changes[name]=self.data.changes[name] or signal()
    return self.data.changes[name]
end
function methods:CaptureFocus() self.data.focused=true end
local function find(root,name)
    if root.Name==name then return root end
    for _,child in ipairs(root.children) do local result=find(child,name);if result then return result end end
end
local Instance={new=function(class)
    assert(class~='MeshPart' and class~='Part' and class~='SpecialMesh' and class~='SurfaceAppearance','Test created replacement geometry/unprocessed PBR')
    local object=node(class)
    if class=='TextButton' then object.MouseButton1Click=signal() end
    return object
end}
local UDim2={new=function(...) return {...} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
local Color3={fromRGB=function(...) return {...} end}
local Enum={AlphaMode={Overlay='Overlay'},Font={SourceSans='SourceSans',SourceSansBold='SourceSansBold'},
    TextXAlignment={Left='Left'},TextYAlignment={Top='Top'}}
local game={GetService=function(_,name) assert(services[name],'Unavailable service '..name);return services[name] end,
    HttpGet=function(_,url)
        requests[#requests+1]=url
        assert(url:find('https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/diagnostics/',1,true)==1,'Repository configuration was not reused')
        if services.failHttp then error('HTTP blocked for test') end
        return 'fixture-body'
    end}
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,child in pairs(value) do result[key]=copy(child) end;return result
end
local function fixture()
    environment={};requests={};createdImages={};createdSurfaces={};clock=100;pending=nil;clipboardText=nil;onSpawnReturn=nil
    buffer,Content=originalBuffer,originalContent
    environment.FunCombat_ExternalRuntime={initialized=true,cancelled=false,
        config={Owner='a65407112-boop',Repository='FunCombatAssets',Branch='main'}}
    local player=node('Player','ActualOwner');local character=node('Model','ActualCharacter')
    player.Character=character;character.Parent=node('Workspace')
    local parent=node('PlayerGui');parent.Parent=player
    local head=node('MeshPart','Head');head.Parent=character
    head.TextureID='rbxassetid://130652123696339';head.Color={R=248/255,G=248/255,B=248/255};head.Transparency=0
    local controls=node('FaceControls');controls.Parent=head
    head.data.avatar=true;controls.data.avatar=true
    local data=copy(originalData)
    local asset={CreateEditableImage=function(_,options)
        local object=node('EditableImage');object.data.options=options
        object.WritePixelsBuffer=function(_,position,size,pixels)
            assert(position.X==0 and position.Y==0,'Pixel origin was changed')
            object.data.pixels=buffer.tostring(pixels);object.data.dimensions=size
        end
        createdImages[#createdImages+1]=object;return object
    end,CreateSurfaceAppearanceAsync=function(_,content)
        assert(content.ColorMap.Object==createdImages[#createdImages],'Surface was not created from the original RGBA image')
        if services.failSurface then error('Native surface creation denied') end
        if services.stallSurface then pending=coroutine.running();coroutine.yield() end
        local object=node('SurfaceAppearance');createdSurfaces[#createdSurfaces+1]=object
        if services.changeTextureDuringSurface then head.data.TextureID='rbxassetid://999' end
        if services.restoreAfterAccepted then
            onSpawnReturn=function()
                local runtime=environment.FunCombat_HeadTextureTest
                find(runtime.gui,'Restore').MouseButton1Click:Fire()
            end
        end
        return object
    end}
    services={Players={LocalPlayer=player},HttpService={JSONDecode=function() return data end,
        JSONEncode=function(_,report) assert(report.sourceTexture=='rbxassetid://130652123696339');return 'copied snapshot: '..tostring(report.stage) end},
        AssetService=asset,CoreGui=node('CoreGui')}
    return player,character,head,data
end
local function start()
    runHeadTest()
    local runtime=environment.FunCombat_HeadTextureTest
    assert(runtime and runtime.gui and runtime.gui.Parent,'Manual texture test window is missing')
    return runtime
end
local function click(runtime,name) assert(find(runtime.gui,name),'Missing button '..name).MouseButton1Click:Fire() end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
    if not ok then failures[#failures+1]=name..': '..tostring(why) end
end
'''
checks = r'''
check('opening the separate window preserves appearance and does not fetch',function()
    local _,_,head=fixture();local runtime=start()
    assert(#requests==0 and #createdImages==0 and #head.children==1,'Opening the test changed the head')
    click(runtime,'Copy');assert(clipboardText and clipboardText:find('copied snapshot',1,true),'No-console copy is missing')
end)
check('test uses exact original RGBA, native Overlay and unchanged head color',function()
    local _,_,head=fixture();local runtime=start();click(runtime,'Test')
    assert(runtime.report.stage=='applied','Original alpha test did not apply: '..tostring(runtime.report.error))
    local image,surface=createdImages[1],createdSurfaces[1]
    assert(#image.data.pixels==1048576 and image.data.dimensions.X==512 and image.data.dimensions.Y==512,'Original pixels were resized')
    local a,b=1,0;for i=1,#image.data.pixels do a=(a+string.byte(image.data.pixels,i))%65521;b=(b+a)%65521 end
    assert(b*65536+a==4278240354,'Transparent RGB or alpha pixels were repainted')
    assert(surface.Parent==head and surface.AlphaMode=='Overlay','Original face was not overlaid over Head.Color')
    assert(head.TextureID=='rbxassetid://130652123696339' and head.Color.R==248/255,'Source texture/color changed')
    assert(runtime.report.renderVerified~=true,'Offline/native success was presented as render confirmation')
    click(runtime,'Restore');assert(image.data.destroyed and surface.data.destroyed and #head.children==1,'Restore leaked or destroyed original objects')
end)
check('changed avatar cannot receive a different original face',function()
    local _,_,head=fixture();head.data.TextureID='rbxassetid://999';local runtime=start();click(runtime,'Test')
    assert(runtime.report.error and #requests==0 and #createdImages==0,'A different avatar received this face')
end)
check('preexisting SurfaceAppearance is retained',function()
    local _,_,head=fixture();local original=node('SurfaceAppearance');original.Parent=head;original.data.avatar=true
    local runtime=start();click(runtime,'Test')
    assert(runtime.report.error and #createdImages==0 and original.Parent==head,'Existing avatar PBR was overwritten')
end)
check('malformed pixel counts are rejected before native allocation',function()
    local _,_,head,data=fixture();data.runs[1][1]=0;local runtime=start();click(runtime,'Test')
    assert(runtime.report.error and #createdImages==0 and #head.children==1,'Malformed resource was used')
end)
check('HTTP error is visible and bounded',function()
    fixture();services.failHttp=true;local runtime=start();click(runtime,'Test')
    assert(runtime.report.error:find('HTTP blocked for test',1,true) and #requests==1,'Concrete HTTP failure was hidden or retried forever')
end)
check('unsupported client reports a capability error without changing the head',function()
    fixture();Content=nil;local runtime=start();click(runtime,'Test')
    assert(runtime.report.error and #createdImages==0,'Unavailable modern API was assumed present')
end)
check('native processing failure releases original image copy',function()
    fixture();services.failSurface=true;local runtime=start();click(runtime,'Test')
    assert(runtime.report.error:find('Native surface creation denied',1,true) and createdImages[1].data.destroyed,'Native failure leaked its image or hid the error')
end)
check('texture changes during native processing cannot receive the old original face',function()
    local _,_,head=fixture();services.changeTextureDuringSurface=true;local runtime=start();click(runtime,'Test')
    assert(runtime.report.stage=='failed' and runtime.report.error,'Changed texture was treated as the same original source')
    assert(createdSurfaces[1].data.destroyed and createdImages[1].data.destroyed and #head.children==1,'Old face replaced the updated avatar')
end)
check('native timeout rejects late surface instead of changing a stale head',function()
    local _,_,head=fixture();services.stallSurface=true;local runtime=start();click(runtime,'Test')
    assert(runtime.report.error and runtime.report.error:lower():find('timed out',1,true),'Native wait did not time out')
    assert(pending and coroutine.resume(pending),'Timed-out engine operation did not resume')
    assert(createdSurfaces[1].data.destroyed and #head.children==1,'Late native completion mutated the avatar')
end)
check('Restore between accepted native completion and return releases the unattached surface',function()
    local _,_,head=fixture();services.restoreAfterAccepted=true;local runtime=start();click(runtime,'Test')
    assert(createdSurfaces[1].data.destroyed and createdImages[1].data.destroyed,'Cancelled accepted native result leaked')
    assert(#head.children==1 and runtime.report.stage=='restored','Cancelled comparison was attached or overwrote Restore')
end)
check('rerun restores the previous test before replacing its window',function()
    local _,_,head=fixture();local previous=start();click(previous,'Test');local old=previous.gui
    local next=start()
    assert(old.data.destroyed and next~=previous and #head.children==1,'Repeated execution left duplicate visuals/windows')
end)
check('head removal restores resources and expires this comparison',function()
    local player,character,head=fixture();local runtime=start();click(runtime,'Test')
    player.Character=node('Model','Respawned');head.AncestryChanged:Fire()
    assert(createdSurfaces[1].data.destroyed and createdImages[1].data.destroyed,'Respawn leaked the temporary texture')
    click(runtime,'Test');assert(#createdImages==1,'An expired comparison modified the new avatar')
end)
check('removing the whole character releases the overlay without detaching Head first',function()
    local _,character,head=fixture();local runtime=start();click(runtime,'Test')
    character.Parent=nil;head.AncestryChanged:Fire()
    assert(createdSurfaces[1].data.destroyed and createdImages[1].data.destroyed,'Removed ancestor retained native resources')
end)
check('changing Player.Character releases the overlay before old Head ancestry changes',function()
    local player,_,head=fixture();local runtime=start();click(runtime,'Test')
    player.Character=node('Model','NextCharacter');player:GetPropertyChangedSignal('Character'):Fire()
    assert(createdSurfaces[1].data.destroyed and createdImages[1].data.destroyed,'Character replacement retained native resources')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Head texture test boundaries passed: '..total..'. No Roblox rendering claim.')
'''
source_path = ROOT / 'head_test.lua'
source = source_path.read_text() if source_path.exists() else 'return nil'
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / 'head_texture.spec.luau'
    path.write_text('local originalData=' + lua(document) + '\n' + header + '\nrunHeadTest=function()\n' + source + '\nend\n' + checks)
    result = subprocess.run([args.luau, str(path)], text=True, capture_output=True)
    print(result.stdout, end='')
    print(result.stderr, end='', file=sys.stderr)
    sys.exit(result.returncode)
