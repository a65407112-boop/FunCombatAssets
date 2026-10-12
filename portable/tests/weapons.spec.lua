local Mock=dofile('portable/tests/roblox_mock.lua');Mock.install()
local playerGui=Mock.object('Folder','PlayerGui');local character=Mock.object('Model','Proxy',playerGui)
local arm=Mock.object('Part','Right Arm',character);arm.CFrame=Mock.cf(10);arm.Anchored=true
local attachment=Mock.object('Attachment','RightGripAttachment',arm);attachment.CFrame=Mock.cf(2)
local tool=Mock.object('Tool','Sword');tool.Grip=Mock.cf(3)
local handle=Mock.object('MeshPart','Handle',tool);handle.CFrame=Mock.cf(100)
local blade=Mock.object('Part','Blade',tool);blade.CFrame=Mock.cf(104)
local current={character=character,weapon='Sword'}
local ctx={report=function(e)error(e)end,state={onChanged=function()return function()end end,all=function()return {}end,get=function()return current end},
    network={on=function()return function()end end},assets={clone=function()return tool:Clone()end}}
ctx.cleanup=dofile('client/cleanup.lua')(ctx)
local f=io.open('portable/weapons.lua');local path=f and 'portable/weapons.lua'or 'client/weapons.lua';if f then f:close()end
local weapons=dofile(path)(ctx);weapons:update(current)
local model=assert(weapons:get(character));local h=assert(model:FindFirstChild('Handle',true))
assert(h.Anchored and not h.CanCollide,'Portable weapons must stay anchored and non-colliding; engine grips cannot drive their parts')
local grip=assert(arm:FindFirstChild('RightGrip'));grip.Transform=Mock.cf(5)
assert(type(weapons.draw)=='function','Portable weapons must render the current animated RightGrip explicitly')
weapons:draw(character);assert(h.CFrame.value==14,'Grip must use current arm, original Tool.Grip and animated Transform')
assert(model:FindFirstChild('Blade',true).CFrame.value==18,'All rigid weapon parts must follow the same handle frame')
arm.CFrame=Mock.cf(20);weapons:draw(character);assert(h.CFrame.value==24,'Weapon must follow a moved proxy in the same render pass')
weapons:destroy();assert(model.Destroyed and not arm:FindFirstChild('RightGrip'),'Unload must remove the cosmetic grip')
print('KINEMATIC WEAPON TESTS 5')
