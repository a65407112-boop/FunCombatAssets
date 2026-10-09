"""Exercise actual server Avatar code without Roblox asset/physics services."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += r'''
Enum.HumanoidRigType={R6=0,R15=1}
Enum.BodyPart={Head=0,Torso=1,LeftArm=2,RightArm=3,LeftLeg=4,RightLeg=5}
local Players={}
local AssetService={}
local InsertService={}
game.GetService=function(_,name)
    if name=='Players' then return Players end
    if name=='AssetService' then return AssetService end
    if name=='InsertService' then return InsertService end
    error('Unexpected avatar service '..name)
end
local function fixture(native)
    now=100
    Players.GetHumanoidDescriptionFromUserIdAsync=nil
    InsertService.LoadAsset=nil
    local owner=node('Player','Owner');owner.Parent=true;owner.UserId=123
    local c=node('Model','Actor');c.Parent=true;owner.Character=c
    local hum=node('Humanoid','Humanoid');hum.Parent=c;hum.RequiresNeck=false
    local torso=node('Part','Torso');torso.Parent=c
    local old=node(native and 'MeshPart' or 'Part','Head');old.Parent=c;old.CFrame=frame(1,2,3)
    old.Color='classic-template-color';old.TextureID='old-head-texture'
    local face=node('Decal','face');face.Parent=old
    local mesh=node('SpecialMesh','ClassicHeadMesh');mesh.Parent=old
    local prompt=node('ProximityPrompt','OriginalPrompt');prompt.Parent=old
    local neck=node('Motor6D','Neck');neck.Part0=torso;neck.Part1=old;neck.C0=frame(0,1,0);neck.C1=frame(0,-0.5,0);neck.Parent=torso
    local accessory=node('Accessory','OriginalHair');accessory.Parent=c
    local handle=node('Part','Handle');handle.Parent=accessory
    local attachment=node('Attachment','HairAttachment');attachment.CFrame=frame(0,0.25,0);attachment.Parent=handle
    local weld=node('Weld','AccessoryWeld');weld.Part0=handle;weld.Part1=old;weld.C0=attachment.CFrame;weld.C1=frame();weld.Parent=handle
    local desc=node('HumanoidDescription','OriginalDescription')
    desc.Head=12345;desc.Face=4567;desc.MoodAnimation=88;desc.StaticFacialAnimation=true;desc.HeadScale=1;desc.HeadColor='avatar-color'
    desc.LeftArm=11;desc.LeftLeg=12;desc.RightArm=13;desc.RightLeg=14;desc.Torso=15
    function hum:ApplyDescription(value)
        self.description=value
        if native then local controls=node('FaceControls','FaceControls');controls.Parent=old end
    end
    Players.GetHumanoidDescriptionFromUserId=function(_,id) assert(id==123);return desc end
    local donor
    Players.CreateHumanoidModelFromDescriptionAsync=nil
    Players.CreateHumanoidModelFromDescription=function(_,value,rigType)
        assert(rigType==0,'Fresh head was generated for a different rig type')
        assert(value.Head==12345 and value.Face==4567,'Donor did not request the actual avatar assets')
        assert(value.MoodAnimation==88 and value.StaticFacialAnimation==false,'Donor lost facial settings')
        assert(value.HairAccessory==nil or value.HairAccessory=='','Head donor fetched unrelated accessories')
        donor=node('Model','IsolatedDonor')
        local head=node('MeshPart','Head');head.MeshId='fixture-original-head-mesh';head.Parent=donor
        head.TextureID='native-head-texture';head.Color='avatar-color'
        local surface=node('SurfaceAppearance','OriginalNativeSurface');surface.ColorMap='original-native-color-map';surface.Parent=head
        local controls=node('FaceControls','FaceControls');controls.Parent=head
        local bone=node('Bone','OriginalFacialBone');bone.Parent=head
        local a=node('Attachment','HairAttachment');a.CFrame=frame(0,0.5,0);a.Parent=head
        return donor
    end
    AssetService.LoadAssetAsync=function(_,id)
        assert(id==88,'Mood resolver used a head or invented asset ID')
        local asset=node('Model','OriginalMoodAsset')
        local group=node('Folder','R15Anim');group.Parent=asset
        local mood=node('StringValue','mood');mood.Value='';mood.Parent=group
        local animation=node('Animation','Animation1');animation.AnimationId='rbxassetid://89';animation.Parent=mood
        return asset
    end
    return owner,c,hum,old,neck,weld,prompt,desc,function() return donor end
end
'''
code += '\nlocal Avatar=(function()\n' + (ROOT / 'Builder/templates/server/Avatar.lua').read_text() + '\nend)()\n'
code += r'''
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Avatar: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
check('R6 normalization retains the actual head, face and mood IDs',function()
    local p,c,h,_,_,_,_,d=fixture(true)
    assert(Avatar.prepare(p,c,h))
    assert(d.Head==12345 and d.Face==4567 and d.MoodAnimation==88,'Original head/face/mood was discarded')
    assert(d.StaticFacialAnimation==false,'Facial animation stayed disabled')
    for _,key in ipairs({'LeftArm','LeftLeg','RightArm','RightLeg','Torso'}) do assert(d[key]==0,'R6 body was replaced') end
end)
check('existing FaceControls do not retain the stale classic-template head',function()
    local p,c,h,old,_,_,_,_,donor=fixture(true)
    assert(Avatar.prepare(p,c,h));assert(c:FindFirstChild('Head')~=old and donor() and donor().destroyed,
        'FaceControls presence kept the stale head instead of the fresh native R6 head')
end)
check('R6 head adapter keeps original facial data and rewires neck, hair and prompt',function()
    local p,c,h,old,neck,hair,prompt,_,donor=fixture(false)
    assert(Avatar.prepare(p,c,h))
    local head=assert(c:FindFirstChild('Head'))
    assert(head~=old and head:IsA('MeshPart') and head:FindFirstChildOfClass('FaceControls'),'Dynamic head was not installed')
    assert(head.MeshId=='fixture-original-head-mesh' and head:FindFirstChild('OriginalFacialBone'),'Original facial resource was altered')
    assert(neck.Part1==head and hair.Part1==head,'Neck/accessory still references the deleted head')
    assert(hair.C1[2]==0.5 and hair.C0[2]==0.25,'Hair was not attached to the original dynamic-head attachment')
    assert(prompt.Parent==head and old.destroyed,'Head swap deleted a necessary original prompt or retained a second head')
    assert(donor().destroyed,'Temporary native R6 donor leaked into the server')
    assert(c:GetAttribute('FunCombatMoodAnimation')==88,'External client cannot restore the actual facial mood')
end)
check('fresh native head retains its texture and PBR without classic visual overlays',function()
    local p,c,h,old=fixture(true);assert(Avatar.prepare(p,c,h))
    local head=c:FindFirstChild('Head');local surface=head:FindFirstChildOfClass('SurfaceAppearance')
    assert(head~=old and head.TextureID=='native-head-texture' and head.Color=='avatar-color',
        'Fresh native visual properties were replaced by classic template values')
    assert(surface and surface.ColorMap=='original-native-color-map','Native PBR appearance was lost')
    assert(not head:FindFirstChildOfClass('SpecialMesh') and not head:FindFirstChild('face'),
        'The old classic mesh or face decal was copied over the dynamic head')
end)
check('mood package resolves to its contained animation and native Animate hook',function()
    local p,c,h=fixture(true);assert(Avatar.prepare(p,c,h))
    local animate=c:FindFirstChild('Animate');local mood=animate and animate:FindFirstChild('mood')
    local animation=mood and mood:FindFirstChildOfClass('Animation')
    assert(animate and animate:IsA('LocalScript') and animation and animation.AnimationId=='rbxassetid://89',
        'Native facial hook is absent or contains the mood package instead of its animation')
    assert(c:GetAttribute('FunCombatMoodAnimation')==88 and c:GetAttribute('FunCombatMoodClipId')==89,
        'Package identity and playable animation reference were conflated')
end)
check('an unavailable head asset retains a playable R6 character with a specific error',function()
    local p,c,h,old=fixture(false)
    Players.CreateHumanoidModelFromDescription=function() error('asset access denied') end
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and c:FindFirstChild('Head')==old and why and why:find('12345') and why:find('asset access denied'),
        'Head failure was silent or prevented the R6 character from binding')
end)
check('appearance warnings persist for a client arriving after the original server Error',function()
    local p,c,h=fixture(false)
    local create=Players.CreateHumanoidModelFromDescription
    Players.CreateHumanoidModelFromDescription=function() error('asset access denied') end
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and why and c:GetAttribute('FunCombatAvatarDiagnostic')==why,
        'Late clients cannot recover the original head loading failure')
    Players.CreateHumanoidModelFromDescription=create
    assert(Avatar.prepare(p,c,h))
    assert(c:GetAttribute('FunCombatAvatarDiagnostic')=='','A successful preparation retained a stale head warning')
end)
check('retained head trails keep valid references when a donor attachment replaces the old attachment',function()
    local p,c,h,old=fixture(false)
    local attachment=node('Attachment','HairAttachment');attachment.Parent=old
    local trail=node('Trail','OriginalTrail');trail.Attachment0=attachment;trail.Attachment1=attachment;trail.Parent=old
    assert(Avatar.prepare(p,c,h))
    local head=c:FindFirstChild('Head');local actual=head:FindFirstChild('HairAttachment')
    assert(trail.Parent==head and trail.Attachment0==actual and trail.Attachment1==actual and actual.Parent==head,
        'Original Trail still references destroyed head attachments')
end)
check('late head loading after respawn disposes the donor without replacing the old head',function()
    local p,c,h,old,_,_,_,_,donor=fixture(false)
    local create=Players.CreateHumanoidModelFromDescription;local pending
    Players.CreateHumanoidModelFromDescription=function(...)
        pending=coroutine.running();coroutine.yield();return create(...)
    end
    local originalWait=wait
    wait=function(s)
        now+=s or 0.05;p.Character=node('Model','Replacement');p.Character.Parent=true
    end
    local ready=Avatar.prepare(p,c,h);wait=originalWait
    assert(not ready,'Replaced character finished initialization')
    assert(pending,'Isolated loading of the actual head was never requested')
    assert(coroutine.resume(pending));assert(c:FindFirstChild('Head')==old and donor().destroyed,'Late donor mutated the cancelled character or leaked')
end)
check('a slow isolated head request times out without locking gameplay',function()
    local p,c,h,old,_,_,_,_,donor=fixture(false)
    local create=Players.CreateHumanoidModelFromDescription;local pending
    Players.CreateHumanoidModelFromDescription=function(...) pending=coroutine.running();coroutine.yield();return create(...) end
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and why and now<=108.1,'Isolated head loading did not release initialization within its deadline')
    assert(c:GetAttribute('FunCombatAvatarDiagnostic')==why,'Late clients cannot recover the original head timeout')
    assert(coroutine.resume(pending));assert(c:FindFirstChild('Head')==old and donor().destroyed,'Timed-out donor changed the bound body')
end)
check('user-ID dummies share the head adapter without requiring owner.Character to match',function()
    local p,c,h,old=fixture(false);p.Character=node('Model','OwnerCharacter');p.Character.Parent=true
    assert(type(Avatar.prepareDummy)=='function','Dummy appearance still uses a separate head reset')
    assert(Avatar.prepareDummy(p,c,h,123));assert(c:FindFirstChild('Head')~=old,'Dummy did not receive its actual dynamic head')
end)
check('modern head metadata survives while unrelated body metadata cannot replace the R6 body',function()
    local p,c,h,_,_,_,_,desc=fixture(true)
    local head=node('BodyPartDescription','NativeHead');head.BodyPart=Enum.BodyPart.Head;head.HeadShape='owned-head-shape';head.Parent=desc
    local torso=node('BodyPartDescription','ForeignBody');torso.BodyPart=Enum.BodyPart.Torso;torso.AssetId=777
    torso.Color='original-torso-color';torso.Instance=node('Model','BodyOverride');torso.Parent=desc
    local apply=h.ApplyDescription
    h.ApplyDescription=function(self,value)
        assert(value:FindFirstChild('NativeHead').HeadShape=='owned-head-shape','Native head metadata was lost during appearance application')
        local body=value:FindFirstChild('ForeignBody')
        assert(body and body.Color=='original-torso-color','R6 normalization discarded the body color metadata')
        assert(body.AssetId==0 and body.Instance==nil,'Structured body metadata replaced the original R6 body')
        return apply(self,value)
    end
    local create=Players.CreateHumanoidModelFromDescription
    Players.CreateHumanoidModelFromDescription=function(self,value,rig)
        assert(value:FindFirstChild('NativeHead').HeadShape=='owned-head-shape','Head donor discarded the actual HeadShape')
        return create(self,value,rig)
    end
    local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
end)
local function bodyColorFixture()
    local p,c,h,old,neck,hair,prompt,desc=fixture(true)
    local palette={
        {part='Torso',field='TorsoColor',color='original-torso-color'},
        {part='Left Arm',field='LeftArmColor',enum='LeftArm',color='original-left-arm-color'},
        {part='Right Arm',field='RightArmColor',enum='RightArm',color='original-right-arm-color'},
        {part='Left Leg',field='LeftLegColor',enum='LeftLeg',color='original-left-leg-color'},
        {part='Right Leg',field='RightLegColor',enum='RightLeg',color='black'},
    }
    for _,entry in ipairs(palette) do
        desc[entry.field]=entry.color
        local part=c:FindFirstChild(entry.part)
        if not part then part=node('Part',entry.part);part.Parent=c end
        part.Color='template-color'
        local body=node('BodyPartDescription',entry.part..'Description')
        body.BodyPart=Enum.BodyPart[entry.enum or entry.part];body.AssetId=777;body.Color=entry.color
        body.Instance=node('Model','ForeignBodyOverride');body.syncColor=entry.field;body.Parent=desc
    end
    -- Roblox documents that removing a BodyPartDescription also updates the
    -- corresponding HumanoidDescription properties. The ordinary node double
    -- cannot model that engine side effect, so this fixture supplies it here.
    local destroy=methods.Destroy
    methods.Destroy=function(self)
        if self:IsA('BodyPartDescription') and self.Parent and self.syncColor then
            self.Parent[self.syncColor]='black'
        end
        return destroy(self)
    end
    local apply=h.ApplyDescription
    h.ApplyDescription=function(self,value)
        apply(self,value)
        for _,entry in ipairs(palette) do c:FindFirstChild(entry.part).Color=value[entry.field] end
    end
    return p,c,h,desc,palette,function() methods.Destroy=destroy end
end
check('R6 preparation preserves distinct torso and limb colors when description children synchronize properties',function()
    local p,c,h,desc,palette,restore=bodyColorFixture()
    local ready,why=Avatar.prepare(p,c,h);restore();assert(ready and not why,why)
    for _,entry in ipairs(palette) do
        assert(c:FindFirstChild(entry.part).Color==entry.color,'Original '..entry.part..' color was reset during R6 normalization')
    end
    local head=c:FindFirstChild('Head')
    assert(head.TextureID=='native-head-texture' and head:FindFirstChildOfClass('FaceControls'),
        'Body color correction changed the already working genuine dynamic head')
end)
check('user-ID dummies preserve their own body palette rather than copying the owner or one uniform color',function()
    local p,c,h,desc,palette,restore=bodyColorFixture()
    p.Character=node('Model','OwnerCharacter');p.Character.Parent=true
    local ready,why=Avatar.prepareDummy(p,c,h,123);restore();assert(ready and not why,why)
    for _,entry in ipairs(palette) do
        assert(c:FindFirstChild(entry.part).Color==entry.color,'Dummy lost its original '..entry.part..' color')
    end
end)
check('a classic default head is generated natively and retains its actual face decal',function()
    local p,c,h,old,neck,_,prompt,desc=fixture(false);desc.Head=0;desc.Face=4567
    Players.CreateHumanoidModelFromDescription=function(_,value,rig)
        assert(value.Head==0 and value.Face==4567 and rig==Enum.HumanoidRigType.R6,'Default head did not use the actual R6 description')
        local donor=node('Model','ClassicDonor');local head=node('Part','Head');head.Parent=donor
        local mesh=node('SpecialMesh','NativeClassicMesh');mesh.Parent=head
        local face=node('Decal','face');face.Texture='original-classic-face';face.Parent=head
        return donor
    end
    AssetService.LoadAssetAsync=function() error('Classic head must not request a facial mood') end
    local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
    local head=c:FindFirstChild('Head')
    assert(head~=old and head:FindFirstChild('face').Texture=='original-classic-face','Actual classic face was replaced by the template')
    assert(neck.Part1==head and prompt.Parent==head and c:GetAttribute('FunCombatMoodClipId')==0,'Classic head broke gameplay or acquired a fabricated mood')
end)
check('an engine-provided mood hook is reused without another hosted package request',function()
    local p,c,h=fixture(true);local create=Players.CreateHumanoidModelFromDescription
    Players.CreateHumanoidModelFromDescription=function(...)
        local donor=create(...);local animate=node('LocalScript','Animate');animate.Parent=donor
        local mood=node('StringValue','mood');mood.Value='native';mood.Parent=animate
        local clip=node('Animation','Animation1');clip.AnimationId='rbxassetid://91';clip.Parent=mood
        return donor
    end
    AssetService.LoadAssetAsync=function() error('Native hook already contains the actual original animation') end
    local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
    assert(c:GetAttribute('FunCombatMoodClipId')==91,'Native hook was replaced by an assumed package mapping')
end)
check('old servers use InsertService when the modern asset method is absent',function()
    local p,c,h=fixture(true);local load=AssetService.LoadAssetAsync;AssetService.LoadAssetAsync=nil
    InsertService.LoadAsset=load
    local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
    assert(c:GetAttribute('FunCombatMoodClipId')==89,'Legacy package resolution failed')
end)
check('invalid hosted mood keeps the genuine head and exposes its exact package error',function()
    local p,c,h,old=fixture(true);local loaded
    AssetService.LoadAssetAsync=function() loaded=node('Model','InvalidPackage');return loaded end
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and c:FindFirstChild('Head')~=old and why and why:find('88') and why:find('mood StringValue'),
        'Mood error was silent, discarded the native head, or locked gameplay')
    assert(loaded.destroyed and c:GetAttribute('FunCombatMoodClipId')==0,'Malformed package leaked or became a playable ID')
end)
check('hosted mood data cannot bring executable descendants into the live character',function()
    local p,c,h=fixture(true);local load=AssetService.LoadAssetAsync;local asset
    AssetService.LoadAssetAsync=function(...)
        asset=load(...);local mood=asset:FindFirstChild('mood',true)
        local clip=mood:FindFirstChildOfClass('Animation')
        local weight=node('NumberValue','Weight');weight.Value=10;weight.Parent=clip
        local script=node('Script','Untrusted');script.Parent=weight
        return asset
    end
    local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
    local mood=c:FindFirstChild('Animate'):FindFirstChild('mood')
    assert(not mood:FindFirstChild('Untrusted',true) and mood:FindFirstChild('Weight',true).Value==10 and asset.destroyed,
        'Hosted executable data escaped sanitization or original weighting was lost')
end)
check('a late hosted mood after respawn cannot update the old head and releases the asset',function()
    local p,c,h=fixture(true);local load=AssetService.LoadAssetAsync;local pending,asset
    AssetService.LoadAssetAsync=function(...) pending=coroutine.running();coroutine.yield();asset=load(...);return asset end
    local originalWait=wait
    wait=function(s) now+=s or 0.05;p.Character=node('Model','NewCharacter');p.Character.Parent=true end
    local ready=Avatar.prepare(p,c,h);wait=originalWait
    assert(not ready and pending,'Respawn did not cancel mood initialization')
    assert(coroutine.resume(pending));assert(asset.destroyed and c:GetAttribute('FunCombatMoodClipId')==0,
        'Late mood changed the old character or leaked the package')
end)
check('a slow mood request releases gameplay and rejects its late completion',function()
    local p,c,h=fixture(true);local load=AssetService.LoadAssetAsync;local pending,asset
    AssetService.LoadAssetAsync=function(...) pending=coroutine.running();coroutine.yield();asset=load(...);return asset end
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and why and why:find('mood package 88') and now<=108.1,'Mood request locked gameplay or gave an unrelated timeout')
    assert(coroutine.resume(pending));assert(asset.destroyed and c:GetAttribute('FunCombatMoodClipId')==0,'Late mood mutated the bound character')
end)
check('a missing original Neck prevents a destructive head swap',function()
    local p,c,h,old,neck,_,_,_,donor=fixture(true);neck:Destroy()
    local ready,why=Avatar.prepare(p,c,h)
    assert(ready and c:FindFirstChild('Head')==old and why and why:find('Neck is missing') and donor().destroyed,
        'A missing original connection destroyed the old head or hid the actual error')
end)
check('old facial Bones are not grafted into the native head as gameplay attachments',function()
    for _,name in ipairs({'OriginalFacialBone','OldUniqueBone'}) do
        local p,c,h,old=fixture(true)
        local bone=node('Bone',name);bone.Parent=old
        local nested=node('Bone','OldFacialSubtree');nested.Parent=bone
        local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
        local head=c:FindFirstChild('Head')
        assert(head:FindFirstChild('OriginalFacialBone') and not head:FindFirstChild('OldFacialSubtree',true)
            and not head:FindFirstChild('OldUniqueBone'),
            'Old Bone inherited Attachment and contaminated the intact native facial rig')
        assert(bone.destroyed and nested.destroyed,'Old facial bones escaped old head cleanup')
    end
end)
check('gameplay attachments retain their prompts without bringing nested old facial Bones',function()
    for _,name in ipairs({'HairAttachment','LegacyGameAttachment'}) do
        local p,c,h,old,_,_,prompt=fixture(true)
        local attachment=node('Attachment',name);attachment.Parent=old;prompt.Parent=attachment
        local bone=node('Bone','NestedOldBone');bone.Parent=attachment
        local ready,why=Avatar.prepare(p,c,h);assert(ready and not why,why)
        local head=c:FindFirstChild('Head')
        assert(prompt.Parent==head:FindFirstChild(name) and not head:FindFirstChild('NestedOldBone',true) and bone.destroyed,
            'Gameplay attachment lost its prompt or copied old facial bones into the genuine head')
    end
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Avatar regression scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'avatar.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
