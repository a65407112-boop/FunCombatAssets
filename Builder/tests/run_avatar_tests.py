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
local Players={}
game.GetService=function(_,name) assert(name=='Players');return Players end
local function fixture(native)
    now=100
    local owner=node('Player','Owner');owner.Parent=true;owner.UserId=123
    local c=node('Model','Actor');c.Parent=true;owner.Character=c
    local hum=node('Humanoid','Humanoid');hum.Parent=c;hum.RequiresNeck=false
    local torso=node('Part','Torso');torso.Parent=c
    local old=node('Part','Head');old.Parent=c;old.CFrame=frame(1,2,3)
    local face=node('Decal','face');face.Parent=old
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
        assert(rigType==1,'Head fetch changed the live combat rig instead of creating an isolated donor')
        assert(value.Head==12345 and value.Face==4567,'Donor did not request the actual avatar assets')
        assert(value.MoodAnimation==88 and value.StaticFacialAnimation==false,'Donor lost facial settings')
        assert(value.HairAccessory==nil or value.HairAccessory=='','Head donor fetched unrelated accessories')
        donor=node('Model','IsolatedDonor')
        local head=node('MeshPart','Head');head.MeshId='fixture-original-head-mesh';head.Parent=donor
        local controls=node('FaceControls','FaceControls');controls.Parent=head
        local bone=node('Bone','OriginalFacialBone');bone.Parent=head
        local a=node('Attachment','HairAttachment');a.CFrame=frame(0,0.5,0);a.Parent=head
        return donor
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
check('native dynamic heads need no donor request',function()
    local p,c,h,old,_,_,_,_,donor=fixture(true)
    assert(Avatar.prepare(p,c,h));assert(c:FindFirstChild('Head')==old and donor()==nil,'A native dynamic head was replaced')
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
    assert(donor().destroyed,'Temporary R15 donor leaked into the server')
    assert(c:GetAttribute('FunCombatMoodAnimation')==88,'External client cannot restore the actual facial mood')
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
assert(#failures==0,table.concat(failures,'\n'))
print('Avatar regression scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'avatar.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
