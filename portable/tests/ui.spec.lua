local Mock=dofile('portable/tests/roblox_mock.lua');local services=Mock.install()
local player={Name='TodUntitled',DisplayName='TodUntitled',UserId=11556197791,Chatted=Mock.signal()};services.Players={LocalPlayer=player}
local parent=Mock.object('Folder','PlayerGui');player.Character=Mock.object('Model','RealCharacter',parent)
Instance.new=function(cls)error('Restore original GUI packages instead of constructing '..cls..' menus')end
local packageClones={},{};local made={};local templates={}
local function child(p,cls,name)return Mock.object(cls,name,p)end
for _,name in ipairs({'weapon','weaponGui','Gender','title','Subtitles','Emotes','HitboxToggle','mobileButtons','getUp','HitIndicator','stats','Info','society','completionLeader','BillboardGui'})do
 local gui=Mock.object((name=='stats'or name=='Info'or name=='society'or name=='completionLeader'or name=='BillboardGui')and 'BillboardGui'or 'ScreenGui',name);gui.OriginalStyle=true;templates[name]=gui
 child(gui,'TextLabel','TextLabel')
end
for _,name in ipairs({'Bat','Sword','Sword2','Sword3','cat','cat2'})do child(templates.weapon,'TextButton',name)end
child(templates.weaponGui,'ImageButton','ImageButton')
for _,name in ipairs({'Female','Male','Fembxy'})do child(templates.Gender,'TextButton',name)end
child(child(templates.Emotes,'Frame','button'),'ImageButton','ImageButton');local display=child(templates.Emotes,'Frame','display')
for i=1,5 do child(display,'TextButton',tostring(i))end
for _,name in ipairs({'NameText','GenderText'})do child(child(templates.Info,'TextLabel',name),'TextLabel','Background')end
child(child(templates.stats,'Frame','health'),'Frame','Frame');child(child(templates.stats,'Frame','fun'),'Frame','Frame')
child(templates.mobileButtons,'ImageButton','Dash');child(templates.mobileButtons,'ImageButton','GetUp');child(templates.mobileButtons,'ImageButton','R')
local hit=child(templates.HitIndicator,'Frame','Frame');child(hit,'TextLabel','Hits');child(hit,'TextLabel','Damage')
local proxy=Mock.object('Model','FC_Local_11556197791',parent);child(proxy,'Part','Head')
local localRecord={character=proxy,health=75,maxHealth=100,userId=player.UserId,displayName=player.DisplayName}
local onChanged;local selectedGender,selectedWeapon;local ctx={guiParent=function()return parent end,report=function(e)error(e)end,
    config={},catalog={packages={}},avatars={getLocal=function()return localRecord end},state={all=function()return {localRecord}end,onChanged=function(_,fn)onChanged=fn;return function()end end},
    network={on=function()return function()end end},audio={play=function()end},controller={selectGender=function(_,value)selectedGender=value;return true end,equip=function(_,value)selectedWeapon=value;return true end}}
ctx.assets={clone=function(_,key)local name=key:match('^gui/(.+)$');assert(templates[name],'Unexpected original GUI '..tostring(key));packageClones[#packageClones+1]=key;local c=templates[name]:Clone();made[name]=c;return c end}
for name in pairs(templates)do ctx.catalog.packages['gui/'..name]={}end
ctx.cleanup=dofile('client/cleanup.lua')(ctx)
local ui=dofile('portable/ui.lua')(ctx)
assert(ui.roots.Gender.Enabled,'Original Gender selector must open before choosing')
ui.roots.Gender:FindFirstChild('Female',true).Activated:fire();assert(selectedGender=='Female','Original Female button must request a local choice')
localRecord.gender='Female';onChanged(localRecord)
assert(not ui.roots.Gender.Enabled,'Gender must close after the local choice is applied')
ui.roots.weaponGui:FindFirstChildWhichIsA('GuiButton',true).Activated:fire();assert(ui.roots.weapon.Enabled)
ui.roots.weapon:FindFirstChild('Sword2',true).Activated:fire();assert(selectedWeapon==':3','Original Sword2 button must select :3')
localRecord.weapon=':3';onChanged(localRecord);assert(not ui.roots.weapon.Enabled,'Weapon menu must close after an applied equip')
local dashes=0;ctx.controller.dash=function()dashes=dashes+1;return true end
ui.roots.mobileButtons:FindFirstChild('Dash',true).Activated:fire();assert(dashes==1,'Original mobile Dash button must dispatch dash')
services.UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.Q},false);assert(dashes==2,'Q must dispatch the same dash')
services.UserInputService.InputBegan:fire({KeyCode=Enum.KeyCode.Q},true);assert(dashes==2,'Consumed keyboard input must not dash')
ctx.controller.equip=function(_,value)selectedWeapon=value;localRecord.weapon=value;onChanged(localRecord);return true end
ui.roots.weapon.Enabled=true;ui.roots.weapon:FindFirstChild('Sword',true).Activated:fire()
assert(not ui.roots.weapon.Enabled,'A cached synchronous equip must also close the original menu')
local nameLabel
for _,c in ipairs(parent:GetChildren())do local n=c:FindFirstChild('NameText',true);if n then nameLabel=n end end
assert(nameLabel and nameLabel.Text=='TodUntitled','Nametag must use source display name rather than the proxy model ID')
assert(nameLabel:FindFirstChild('Background').Text=='TodUntitled')
for _,gui in pairs(ui.roots)do assert(gui.OriginalStyle,'Original visual properties must remain intact')end
localRecord=nil;onChanged(nil)
assert(not ui.roots.mobileButtons:FindFirstChild('Dash',true).Visible,'Local removal must immediately hide mobile Dash')
print('ORIGINAL GUI TESTS 13')
