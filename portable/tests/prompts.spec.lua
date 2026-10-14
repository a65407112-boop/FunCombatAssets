local Mock=dofile('portable/tests/roblox_mock.lua');Mock.install()
Vector2={new=function(x,y)return {X=x,Y=y}end}
Instance.new=function(cls)local o=Mock.object(cls);if cls=='ProximityPrompt'then o.Triggered=Mock.signal()end;return o end
local install=dofile('portable/prompts.lua');local count=0
local function check(v,why)assert(v,why);count=count+1 end
local config={InteractDistance=6,DownDuration=12}
local ctx={config=config,promptTemplates=assert(__TEST_PROMPT_DATA),controller={}}
ctx.cleanup=dofile('client/cleanup.lua')(ctx);ctx.core=dofile('portable/core.lua').new(config)
local localPlayer={UserId=1};local otherPlayer={UserId=2}
local actor=ctx.core:register('actor');local victim=ctx.core:register('victim');victim.displayName='Target'
ctx.avatars={getLocal=function()return actor end}
local world=Mock.object('Folder','World');local torso=Mock.object('Part','Torso',world)
local e={parts={Torso=torso},scope=ctx.cleanup:scope(),record=victim}
local calls,reports={},{};ctx.controller.carry=function(_,v)calls[#calls+1]={'carry',v}end
ctx.controller.glory=function(_,v)calls[#calls+1]={'execute',v}end
ctx.controller.drop=function()calls[#calls+1]={'drop'}end
ctx.controller.pairedDance=function(_,v)calls[#calls+1]={'dance',v};return ctx.core:dance(actor,v,0,1,4)end
ctx.controller.stopDance=function(_,v)calls[#calls+1]={'stopDance',v};return ctx.core:stopDance(actor,1)end
ctx.report=function(why)reports[#reports+1]=why end
install(ctx,e,localPlayer)
check(#torso:GetChildren()==3,'Restore three native prompts from the actual source, not the two-prompt prototype')
local actual={executePrompt=e.gloryPrompt,carryPrompt=e.prompt,DefaultFun=e.funPrompt}
for name,p in pairs(actual)do
 local expected=ctx.promptTemplates.templates[name].properties
 check(p:IsA('ProximityPrompt')and p.Name==name and p.ActionText==expected.ActionText and p.ObjectText==expected.ObjectText,'Preserve source labels/names/native class')
 check(p.KeyboardKeyCode==Enum.KeyCode[expected.KeyboardKeyCode] and p.GamepadKeyCode==Enum.KeyCode[expected.GamepadKeyCode],'Preserve source keyboard/gamepad keys')
 check(p.UIOffset.X==expected.UIOffset.x and p.UIOffset.Y==expected.UIOffset.y and p.Exclusivity==Enum.ProximityPromptExclusivity.OnePerButton,'Preserve actual source layout/exclusivity')
 check(math.abs(p.HoldDuration-0.3)<1e-6 and p.MaxActivationDistance==6 and p.Style==Enum.ProximityPromptStyle.Default and p.ClickablePrompt and not p.RequiresLineOfSight,'Preserve hold/range/native touch settings')
end
check(not e.prompt.Enabled and not e.gloryPrompt.Enabled and not e.funPrompt.Enabled,'Start with all actions unavailable')
victim.ragdolled=true;e.updatePrompts(actor,5)
check(e.prompt.Enabled and e.gloryPrompt.Enabled and e.funPrompt.Enabled,'A nearby ragdolled target offers all three source UI choices')
e.updatePrompts(actor,7);check(not e.prompt.Enabled and not e.gloryPrompt.Enabled and not e.funPrompt.Enabled,'Out-of-range choices disappear')
e.updatePrompts(actor,5)
e.prompt.Triggered:fire(otherPlayer);e.gloryPrompt.Triggered:fire(otherPlayer);e.funPrompt.Triggered:fire(otherPlayer)
check(#calls==0 and #reports==0,'Foreign input must not trigger the owned local actions')
e.prompt.Triggered:fire(localPlayer);e.gloryPrompt.Triggered:fire(localPlayer)
check(calls[1][1]=='carry'and calls[1][2]==victim and calls[2][1]=='execute'and calls[2][2]==victim,'Existing Carry and combat finisher routing remains working')
e.funPrompt.Triggered:fire(localPlayer)
check(#calls==3 and calls[3][1]=='dance'and calls[3][2]==victim and #reports==0 and actor.dance,'The third source prompt starts the paired ordinary-emote adaptation')
e.updatePrompts(actor,1)
check(e.funPrompt.Name=='stopPrompt'and e.funPrompt.ActionText=='Stop'and e.funPrompt.KeyboardKeyCode==Enum.KeyCode.E and e.funPrompt.Enabled and not e.prompt.Enabled and not e.gloryPrompt.Enabled,'Only the original Stop profile remains during a dance')
e.updatePrompts(ctx.core:register('third'),1);check(not e.funPrompt.Enabled,'An unrelated local actor cannot select Stop on another pair')
e.updatePrompts(actor,1);e.funPrompt.Triggered:fire(localPlayer)
check(calls[4][1]=='stopDance'and not actor.dance and not victim.busy,'Stop routes the owned dance and releases the target')
e.updatePrompts(actor,1);check(e.funPrompt.Name=='DefaultFun'and e.funPrompt.KeyboardKeyCode==Enum.KeyCode.R and e.funPrompt.Enabled,'After Stop the source third-action profile returns')
ctx.controller.pairedDance=function()return false,'Original dance emote fetch failed'end
e.funPrompt.Triggered:fire(localPlayer);check(#reports==1 and reports[1]:find('Original dance emote fetch failed'),'A failed action reports its specific reason')
victim.carriedBy=actor;actor.carrying=victim;victim.downed=true;victim.ragdolled=false;e.updatePrompts(actor,1)
check(e.prompt.Name=='dropPrompt'and e.prompt.ActionText=='Drop'and e.gloryPrompt.Name=='finishHoldPrompt'and e.gloryPrompt.ActionText=='Execute (Finishing Hold)'and not e.funPrompt.Enabled,'Carry transitions to the actual Drop/Finishing Hold source labels')
e.prompt.Triggered:fire(localPlayer);check(calls[5][1]=='drop','Owned carry still selects Drop')
actor.carrying=nil;victim.carriedBy=nil;victim.downed=false;e.updatePrompts(actor,1)
check(not e.prompt.Enabled and not e.gloryPrompt.Enabled and not e.funPrompt.Enabled,'Recovery hides all three downed actions')
e.updatePrompts(nil,1);check(not e.prompt.Enabled and not e.gloryPrompt.Enabled and not e.funPrompt.Enabled,'Respawn/removal without an actor hides all choices')
ctx.cleanup:destroy();e.prompt.Triggered:fire(localPlayer);e.gloryPrompt.Triggered:fire(localPlayer);e.funPrompt.Triggered:fire(localPlayer)
check(#calls==5 and #reports==1,'Cleanup disconnects all three callbacks')
print('ORIGINAL THREE PROMPT TESTS '..count)
