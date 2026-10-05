-- Authoritative adaptation of the supplied CombatFunctions, MoveData and weapon scripts.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Policy=require(script.Parent.Policy)
local Ragdoll=require(script.Parent.Ragdoll)
local Hits=require(script.Parent.HitDetection)
local Moves=require(script.Parent.MoveData)
local Timing=require(script.Parent.AnimationTiming)
local Avatar=require(script.Parent.Avatar)
local C={};C.__index=C
local emotes={"Boston Breakdance","Flex","Rat","Akiyama","idk"}
local adminNames={GuardianWorld=true,ghuisehgfrshdsrgsdd=true,Roblox_ovovo=true}
local actionNames={"Equip","Swing","Dash","GetUp","Emote","Vote","Drop","Gender","Admin","SpawnDummy","SecretDoor","PairSpeed"}
local eventIndex={State=1,Animation=2,StopAnimation=3,Sound=4,Effect=5,Damage=6,Subtitle=7,Awaken=8,Voting=9,Weather=10,Admin=11,Remove=12,Notice=13,Error=14,Pair=15}
local function timeNow() return tick() end
local function cancelConnections(list) for _,v in ipairs(list) do v:Disconnect() end end
local function owner(root,player) if root and root.Parent and not root.Anchored then pcall(function() root:SetNetworkOwner(player) end) end end
local function delay(seconds,fn) coroutine.wrap(function() wait(seconds);fn() end)() end
function C.new(protocol,templates)
    local self=setmetatable({protocol=protocol,templates=templates,records={},players={},gates={},snapshotGates={},
        holds={},dummyOwners={},noRespawn={},connections={},epoch=0,ready=false},C)
    self.event=protocol.folder:FindFirstChild(protocol.config.names[3])
    self.action=protocol.folder:FindFirstChild(protocol.config.names[2])
    self.snapshot=protocol.folder:FindFirstChild(protocol.config.names[4])
    return self
end
function C:emit(kind,data,player)
    data.serverTime=timeNow()
    local id=assert(self.protocol.config.events[eventIndex[kind]],"Unknown presentation")
    if player then self.event:FireClient(player,id,data) else self.event:FireAllClients(id,data) end
end
function C:alive(r) return r and self.records[r.character]==r and r.character.Parent~=nil and r.humanoid.Health>0 and not r.removed end
function C:view(r)
    if not r then return nil end
    local now=timeNow()
    return {alive=self:alive(r),character=r.character,health=r.humanoid.Health,maxHealth=r.humanoid.MaxHealth,
        downed=r.downed,busy=r.busy,stunned=now<(r.stunUntil or 0),ragdolled=r.ragdolled,
        carrying=r.carrying and r.carrying.character,carriedBy=r.carriedBy and r.carriedBy.character,
        attacking=#r.attacks>0,weapon=r.weapon,nextSwing=r.nextSwing,nextDash=r.nextDash,nextEquip=r.nextEquip,
        pairVictim=r.pairVictim and r.pairVictim.character,pairActor=r.pairActor and r.pairActor.character,
        pairPhase=r.interaction and r.interaction.pair and r.interaction.phase,pairMeter=r.funMeter,
        pairReleasing=r.interaction and r.interaction.releasing,
        canGetUp=r.downed and not r.busy and not r.carriedBy and not r.interaction and r.humanoid.Health>=r.humanoid.MaxHealth/2}
end
function C:public(r)
    local view=self:view(r)
    return {character=r.character,userId=r.player and r.player.UserId or 0,displayName=r.displayName,serverTime=timeNow(),
        revision=r.revision,health=view.health,maxHealth=view.maxHealth,dead=not view.alive,
        downed=r.downed,ragdolled=r.ragdolled,busy=r.busy,stunned=view.stunned,
        canAct=Policy.free(view),canGetUp=view.canGetUp,carrying=view.carrying,carriedBy=view.carriedBy,
        weapon=r.weapon,attacking=view.attacking,awakened=r.awakened,gender=r.player and r.player:GetAttribute("Gender") or nil,
        ownerTag=r.player and r.player.Name=="DeluxeyThaLux" or false,getUpProgress=r.getUpCount/20,
        kills=r.player and r.player.leaderstats.Kills.Value or 0,
        killstreak=r.player and r.player.leaderstats.Killstreak.Value or 0,
        completions=r.player and r.player.leaderstats.Completions.Value or 0,
        animation=r.animation,animationRevision=r.animationRevision,funMeter=r.funMeter or 0,
        pairVictim=view.pairVictim,pairActor=view.pairActor,pairPhase=view.pairPhase,
        pairTag=r.interaction and r.interaction.pair and r.interaction.tag,pairReleasing=view.pairReleasing}
end
function C:publish(r)
    if not r or r.removed then return end
    r.revision=r.revision+1
    local view=self:view(r)
    for _,key in ipairs({"downed","ragdolled","awakened","wallBounce"}) do r.character:SetAttribute(key,r[key]==true) end
    r.character:SetAttribute("attacking",view.attacking)
    r.character:SetAttribute("canGetUp",view.canGetUp)
    r.character:SetAttribute("carrying",r.carrying and r.carrying.character.Name or false)
    r.character:SetAttribute("carriedBy",r.carriedBy and r.carriedBy.character.Name or false)
    r.character:SetAttribute("iframes",r.iframes==true)
    r.character:SetAttribute("doing",r.pairVictim~=nil and not view.pairReleasing)
    r.character:SetAttribute("funMeter",r.funMeter or 0)
    local locked=not view.alive or r.downed or r.ragdolled or r.busy or view.stunned or r.carriedBy~=nil
    r.humanoid.WalkSpeed=locked and 0 or r.walkSpeed
    r.humanoid.JumpPower=(locked or r.dashing) and 0 or r.jumpPower
    pcall(function() r.humanoid.JumpHeight=(locked or r.dashing) and 0 or r.jumpHeight end)
    r.humanoid.AutoRotate=not locked
    self:emit("State",self:public(r))
end
function C:animation(r,key,loop,duration)
    r.animationRevision=r.animationRevision+1
    r.animation={key=key,start=timeNow(),revision=r.animationRevision,loop=loop==true,speed=1}
    r.animationExpires=not loop and (timeNow()+(duration or (Timing[key] and Timing[key].duration) or 3)) or nil
    local message={character=r.character}
    for k,v in pairs(r.animation) do message[k]=v end
    self:emit("Animation",message)
end
function C:stopAnimation(r)
    r.animation=nil;r.animationExpires=nil;r.emoting=false;r.animationRevision=r.animationRevision+1
    self:emit("StopAnimation",{character=r.character,revision=r.animationRevision})
end
function C:sound(r,key,duration,speed)
    self:emit("Sound",{character=r.character,key=key,duration=duration,speed=speed})
end
function C:effect(r,key,duration)
    self:emit("Effect",{character=r.character,key=key,duration=duration})
end
function C:setRagdoll(r,value)
    if r.ragdolled==value then return end
    r.ragdolled=value;Ragdoll.set(r.character,value)
    owner(r.root,not value and r.player or nil)
end
function C:cancelAttack(r)
    local hadDash=r.dashing or r.dashBody~=nil or r.dashAt~=nil
    r.attacks={}
    if r.dashBody then r.dashBody:Destroy();r.dashBody=nil end
    r.dashing=false;r.dashAt=nil;r.dashUntil=nil
    if hadDash then owner(r.root,(not r.carrying and not r.ragdolled) and r.player or nil) end
end
function C:clearHolds(character)
    for player,group in pairs(self.holds) do
        for prompt,h in pairs(group) do
            if h.actor==character or h.target==character or not prompt.Parent then group[prompt]=nil end
        end
        if not next(group) then self.holds[player]=nil end
    end
end
function C:restoreCarry(a,v)
    if a.carryWeld then a.carryWeld:Destroy();a.carryWeld=nil end
    a.carrying=nil;v.carriedBy=nil;v.iframes=false
    for part,props in pairs(v.carrySaved or {}) do
        if part.Parent then part.CanCollide=props.collide;part.Massless=props.massless end
    end
    v.carrySaved=nil
    self:stopAnimation(a);self:stopAnimation(v)
    if self:alive(v) and v.downed then self:setRagdoll(v,true) end
    owner(a.root,a.player);owner(v.root,not v.ragdolled and v.player or nil)
    self:clearHolds(a.character);self:clearHolds(v.character)
    self:publish(a);self:publish(v)
end
function C:drop(a)
    local v=a.carrying
    if not v then return end
    self:restoreCarry(a,v)
    if self:alive(v) then self:sound(v,"audio/Uncarry") end
end
function C:release(interaction)
    if not interaction or interaction.released then return end
    interaction.released=true
    if interaction.pair then self:clearPair(interaction) end
    for _,r in ipairs({interaction.a,interaction.v}) do
        if r.interaction==interaction then
            r.interaction=nil;r.busy=false;r.iframes=false;r.root.Anchored=false
            self:stopAnimation(r)
            if self:alive(r) and r.downed then self:setRagdoll(r,true) end
            owner(r.root,not r.ragdolled and r.player or nil)
            self:clearHolds(r.character);self:publish(r)
            if r.pendingAwaken and self:alive(r) then r.pendingAwaken=false;self:awaken(r) end
        end
    end
end
function C:remove(character)
    if self.world then self.world.teleports[character]=nil end
    local r=self.records[character]
    if not r or r.removed then return end
    if r.interaction then self:release(r.interaction) end
    if r.carrying then self:drop(r) end
    if r.carriedBy then self:drop(r.carriedBy) end
    self:cancelAttack(r);self:clearHolds(character)
    r.removed=true;cancelConnections(r.connections);Ragdoll.remove(character)
    self.records[character]=nil
    if r.player and self.players[r.player]==r then self.players[r.player]=nil end
    if self.dummyOwners[character] then self.dummyOwners[character]=nil end
    self:emit("Remove",{character=character,revision=r.revision+1})
end
function C:bind(character,player,displayName)
    if self.records[character] then return self.records[character] end
    local hum=character:FindFirstChildOfClass("Humanoid")
    local root=character:FindFirstChild("HumanoidRootPart")
    local torso=character:FindFirstChild("Torso")
    if not hum or not root or not torso then return nil,"The source requires a complete R6 character" end
    if hum.Health<=0 then return nil,"A dead R6 character cannot initialize gameplay" end
    self.epoch=self.epoch+1
    local r={character=character,player=player,displayName=displayName or (player and player.DisplayName) or character.Name,
        humanoid=hum,root=root,torso=torso,revision=0,animationRevision=0,connections={},attacks={},prompts={},
        weapon="",downed=false,ragdolled=false,busy=false,awakened=false,stunUntil=0,ragdollUntil=0,
        getUpCount=0,nextGetUp=0,nextSwing=0,nextDash=0,nextEquip=0,combo=1,lastSwing=-100,
        walkSpeed=hum.WalkSpeed,jumpPower=hum.JumpPower,jumpHeight=hum.JumpHeight,regenAt=timeNow()+1,epoch=self.epoch,funMeter=0}
    self.records[character]=r
    if player then self.players[player]=r end
    hum.BreakJointsOnDeath=false;hum.RequiresNeck=false
    hum.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
    for _,child in ipairs(character:GetDescendants()) do
        if child:IsA("ProximityPrompt") then child:Destroy() end
    end
    for kind,name in ipairs(self.protocol.config.prompts) do
        local prompt=assert(self.templates.Prompts:FindFirstChild(name),"Missing original combat prompt"):Clone()
        prompt.Parent=torso;r.prompts[kind]=prompt
        r.connections[#r.connections+1]=prompt.PromptButtonHoldBegan:Connect(function(sender)
            if self:promptAllowed(sender,r,kind,prompt) then
                self.holds[sender]=self.holds[sender] or {}
                self.holds[sender][prompt]={started=timeNow(),actor=sender.Character,target=character}
            end
        end)
        r.connections[#r.connections+1]=prompt.PromptButtonHoldEnded:Connect(function(sender)
            local h=self.holds[sender] and self.holds[sender][prompt]
            if h then h.ended=timeNow() end
        end)
        r.connections[#r.connections+1]=prompt.Triggered:Connect(function(sender)
            local h=self.holds[sender] and self.holds[sender][prompt]
            if not h or h.actor~=sender.Character or h.target~=character or not Policy.holdReady(h,timeNow(),prompt.HoldDuration) then return end
            if not self:promptAllowed(sender,r,kind,prompt) then return end
            self.holds[sender][prompt]=nil
            local a=self.players[sender]
            if timeNow()<(a.nextInteraction or 0) then return end
            a.nextInteraction=timeNow()+0.35
            if kind==1 then self:execute(a,r,false)
            elseif kind==2 then self:carry(a,r)
            elseif kind==3 then self:drop(a)
            elseif kind==4 then self:execute(a,r,true)
            elseif kind==5 then self:beginPair(a,r,"Default")
            elseif kind==6 then self:stopPair(a,r) end
        end)
    end
    r.connections[#r.connections+1]=hum.HealthChanged:Connect(function() if not r.removed then self:publish(r) end end)
    r.connections[#r.connections+1]=hum.Died:Connect(function()
        self:cancelAttack(r)
        if r.carrying then self:drop(r) end
        if r.carriedBy then self:drop(r.carriedBy) end
        local link=r.interaction
        local finishingDeath=link and not link.pair and link.v==r and link.stage==3
        if link and not finishingDeath then self:release(link) end
        if not finishingDeath then self:stopAnimation(r);self:setRagdoll(r,true) end
        if player and player:FindFirstChild("leaderstats") then player.leaderstats.Killstreak.Value=0 end
        self:publish(r)
        if not player and self.dummyOwners[character] then delay(5,function() if character.Parent then character:Destroy() end end) end
    end)
    r.connections[#r.connections+1]=character.AncestryChanged:Connect(function(_,parent) if not parent then self:remove(character) end end)
    for _,part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            r.connections[#r.connections+1]=part.Touched:Connect(function(other)
                if self.world then self.world:wallContact(r,other) end
            end)
        end
    end
    if self.world and player then self.world:spawn(r) end
    if not player then owner(root,nil) end
    self:publish(r)
    return r
end
function C:updatePrompts(r)
    local available=self:alive(r) and r.downed and not r.busy
    for kind,prompt in ipairs(r.prompts) do
        if kind==6 then prompt.Enabled=self:alive(r) and r.pairActor~=nil and r.interaction and not r.interaction.releasing or false
        elseif kind==5 then prompt.Enabled=available and not r.carriedBy
        else prompt.Enabled=available and ((kind<=2 and not r.carriedBy) or (kind>=3 and r.carriedBy~=nil)) or false end
    end
end
function C:promptAllowed(player,v,kind,prompt)
    local a=self.players[player]
    if not a or not prompt.Enabled or not self:alive(a) or not self:alive(v) then return false end
    local position=prompt.Parent:IsA("Attachment") and prompt.Parent.WorldPosition or prompt.Parent.Position
    local distance=(a.root.Position-position).Magnitude
    return Policy.interact(self:view(a),self:view(v),kind,distance,prompt.MaxActivationDistance)
end
function C:carry(a,v)
    if not Policy.interact(self:view(a),self:view(v),2,(a.root.Position-v.torso.Position).Magnitude,6) then return end
    self:cancelAttack(a);self:cancelAttack(v);self:stopAnimation(a);self:stopAnimation(v)
    self:setRagdoll(v,false)
    a.carrying=v;v.carriedBy=a;v.iframes=true;v.carrySaved={}
    for _,part in ipairs(v.character:GetDescendants()) do
        if part:IsA("BasePart") then v.carrySaved[part]={collide=part.CanCollide,massless=part.Massless};part.CanCollide=false;part.Massless=true end
    end
    local weld=self.templates:FindFirstChild("CarryWeld"):Clone()
    weld.Part0,weld.Part1=a.torso,v.root
    v.root.CFrame=a.torso.CFrame*weld.C0*weld.C1:Inverse()
    weld.Parent=a.torso;weld.Enabled=true;a.carryWeld=weld
    owner(a.root,nil)
    self:animation(a,"other/carryGrabber",true);self:animation(v,"other/carryGrabbed",true)
    self:sound(v,"audio/Carry");self:publish(a);self:publish(v)
end
function C:kill(v,a)
    if not self:alive(v) then return end
    if a and self:alive(a) and a.player then
        local stats=a.player.leaderstats
        stats.Kills.Value=stats.Kills.Value+1;stats.Killstreak.Value=stats.Killstreak.Value+1
        self:effect(a,"effects/LevelUp/UpKill",2);self:sound(a,"audio/LevelUp")
        if stats.Killstreak.Value==5 and not a.awakened then
            if a.busy then a.pendingAwaken=true else self:awaken(a) end
        end
        self:publish(a)
    end
    v.humanoid.Health=0
end
function C:damage(a,v,move,bypass)
    if not self:alive(a) or not self:alive(v) or (v.iframes and not bypass) or a==v then return end
    local counter=#v.attacks>0
    if v.carrying then self:drop(v) end
    if v.interaction and not bypass then self:release(v.interaction) end
    self:cancelAttack(v)
    if move.kill then self:kill(v,a)
    elseif v.humanoid.Health-move.damage<=0 then
        v.downed=true;v.getUpCount=0;self:stopAnimation(v);self:setRagdoll(v,true)
    else v.humanoid:TakeDamage(move.damage) end
    v.stunUntil=math.max(v.stunUntil,timeNow()+(move.stun or 0))
    if move.ragdoll and not v.busy and self:alive(v) then
        self:stopAnimation(v);self:setRagdoll(v,true);v.ragdollUntil=timeNow()+move.ragdoll
    elseif move.stun_anim and not v.downed and not v.busy and self:alive(v) then self:animation(v,"bat/"..move.stun_anim,false) end
    self:emit("Damage",{character=v.character,amount=move.damage,counter=counter,attacker=a.character,attackerUserId=a.player and a.player.UserId or 0})
    self:effect(v,"effects/Hits/"..move.vfx,2);self:sound(v,"audio/"..move.vfx)
    if counter then self:effect(v,"effects/Counter",2);self:sound(v,"audio/Counter") end
    if (move.kb_speed or 0)>0 and not v.root.Anchored and not v.busy then
        owner(v.root,nil)
        local body=Instance.new("BodyVelocity");body.MaxForce=Vector3.new(move.kb_force,move.kb_force,move.kb_force)
        body.Velocity=a.root.CFrame.LookVector*move.kb_speed;body.Parent=v.root;Debris:AddItem(body,move.kb_duration)
    end
    self:publish(v)
end
function C:execute(a,v,finishing)
    local kind=finishing and 4 or 1
    if not Policy.interact(self:view(a),self:view(v),kind,(a.root.Position-v.torso.Position).Magnitude,6) then return end
    if finishing then self:restoreCarry(a,v) end
    self:cancelAttack(a);self:cancelAttack(v);self:setRagdoll(v,false)
    local now=timeNow()
    local link={a=a,v=v,started=now,finishing=finishing,stage=0,released=false}
    a.interaction,v.interaction=link,link;a.busy,v.busy=true,true;a.iframes,v.iframes=true,true
    a.root.Anchored=true;v.root.CFrame=a.root.CFrame;v.root.Anchored=true
    local prefix=finishing and "finishHold" or "grip"
    self:animation(a,"bat/"..prefix.."Attacker",false,finishing and 2.9 or 8.5)
    self:animation(v,"bat/"..prefix.."Victim",false,finishing and 2.9 or 8.5)
    if finishing then
        self:sound(a,"audio/Voice2")
        self:emit("Subtitle",{character=a.character,text="I'm not done beating you up!",duration=1.5})
        self:emit("Subtitle",{character=v.character,text="I'm not done beating you up!",duration=1.5})
        self:damage(a,v,Moves.get_data("BACK_START"),true)
    end
    self:publish(a);self:publish(v)
end
function C:advanceExecution(link,now)
    if link.released then return end
    if not self:alive(link.a) or (link.stage<3 and not self:alive(link.v)) or not link.v.character.Parent then self:release(link);return end
    local elapsed=now-link.started
    if link.finishing then
        if link.stage==0 and elapsed>=1.1 then
            link.stage=1;self:sound(link.a,"audio/DioVoice");self:damage(link.a,link.v,Moves.get_data("BACK_BREAK"),true)
        end
        if link.stage==1 and elapsed>=1.7 then link.stage=3;self:damage(link.a,link.v,Moves.get_data("GRIP_FINISHER"),true) end
        if elapsed>=2.9 then self:release(link) end
    else
        if link.stage==0 and elapsed>=0.6 then link.stage=1;self:damage(link.a,link.v,Moves.get_data("GRIP_HIT"),true) end
        if link.stage==1 and elapsed>=2.1 then
            link.stage=2;self:sound(link.a,"audio/Voice1")
            self:emit("Subtitle",{character=link.a.character,text="I'll kill you!",duration=1})
            self:emit("Subtitle",{character=link.v.character,text="I'll kill you!",duration=1})
        end
        if link.stage==2 and elapsed>=3.5 then link.stage=3;self:damage(link.a,link.v,Moves.get_data("GRIP_FINISHER"),true) end
        if elapsed>=8.5 then self:release(link) end
    end
end
function C:awaken(r)
    if r.awakened or not self:alive(r) then return end
    self:cancelAttack(r);self:stopAnimation(r)
    r.awakened=true;r.busy=true;r.iframes=true;r.awakenUntil=timeNow()+2.4
    self:animation(r,"other/awaken",false,2.4);self:sound(r,"audio/Awaken")
    self:emit("Subtitle",{character=r.character,text="I'm fired up now!",duration=1.2})
    self:emit("Awaken",{character=r.character})
    self:emit("Notice",{category="awaken",text=r.displayName.." Has Awakened"})
    self:publish(r)
    local epoch=r.epoch
    delay(0.4,function()
        if self:alive(r) and r.epoch==epoch and r.awakened then
            self:effect(r,"effects/circles",2);self:effect(r,"effects/Killstreak",2);self:sound(r,"audio/Awaken2")
        end
    end)
end
function C:swing(r)
    local now=timeNow()
    if now-r.lastSwing>2 then r.combo=1 end
    local combo=r.combo
    local move=Moves.get_data(combo==3 and "BIG_SWING" or "SWING_"..combo)
    r.combo=combo%3+1;r.lastSwing=now;r.nextSwing=now+(combo==3 and 1.1 or 0.4)
    self:stopAnimation(r);self:animation(r,"bat/swing_"..combo,false)
    local attack={move=move,started=now,activeAt=now+move.startup/60,ends=now+(move.startup+move.active)/60,hit={},nextDraw=0,weapon=r.weapon}
    r.attacks[#r.attacks+1]=attack
    if combo==3 then delay(0.7,function()
        if self:alive(r) and r.weapon==attack.weapon and timeNow()<=attack.ends then
            self:sound(r,"weapons/"..r.weapon.."/audio/Swing",nil,math.random(50,150)/100);self:effect(r,"weapon/Trail",0.5)
        end
    end) else self:sound(r,"weapons/"..r.weapon.."/audio/Swing",nil,math.random(50,150)/100);self:effect(r,"weapon/Trail",0.5) end
    self:publish(r)
end
function C:dash(r,payload)
    local direction=payload and payload.direction
    if direction~=nil and (typeof(direction)~="Vector3" or not Policy.finite(direction.X) or not Policy.finite(direction.Y) or not Policy.finite(direction.Z) or direction.Magnitude>2) then return end
    direction=direction or r.humanoid.MoveDirection
    direction=Vector3.new(direction.X,0,direction.Z)
    if direction.Magnitude<0.01 then direction=Vector3.new(r.root.CFrame.LookVector.X,0,r.root.CFrame.LookVector.Z) end
    if direction.Magnitude<0.01 then return end
    r.dashDirection=direction.Unit;r.dashDistance=r.awakened and 25 or 18
    r.nextDash=timeNow()+1.35;r.dashAt=timeNow()+0.15;r.dashUntil=r.dashAt+0.3;r.dashing=true
    self:sound(r,"weapons/"..r.weapon.."/audio/DashSound")
    self:sound(r,"weapons/"..r.weapon.."/audio/"..(r.awakened and "awakened" or "normal"))
    self:effect(r,"effects/dash_limbs",0.3)
    if r.humanoid.FloorMaterial~=Enum.Material.Air then self:effect(r,"effects/dash_smoke",0.3) end
    owner(r.root,nil);self:publish(r)
end
function C:equip(r,name)
    self:cancelAttack(r);self:stopAnimation(r)
    local old=r.weapon;r.weapon=name;r.combo=1
    if name=="" then
        r.nextEquip=timeNow()+0.3
        if old~="" then self:sound(r,"weapons/"..old.."/audio/Unequip");self:animation(r,"bat/unequip",false) end
    else
        r.nextEquip=timeNow()+1.75;r.nextSwing=r.nextEquip
        self:animation(r,"bat/flourish",false);self:sound(r,"weapons/"..name.."/audio/Equip")
        local epoch=r.epoch
        delay(1.5,function() if self:alive(r) and r.epoch==epoch and r.weapon==name then self:sound(r,"weapons/"..name.."/audio/Equip2") end end)
    end
    self:publish(r)
end
function C:emote(r,name)
    self:stopAnimation(r)
    if name=="Stop" then self:publish(r);return end
    local key,loop
    local index=tonumber(name)
    if index then key="Emotes/"..emotes[index];loop=Timing[key].loop
    else
        if name=="dance" then name="dance"..math.random(1,3) end
        local variant=name:match("^dance") and math.random(1,3) or 1
        key="chat/"..name.."/"..variant;loop=name:match("^dance")~=nil
    end
    r.emoting=true
    self:animation(r,key,loop,not index and not loop and 3 or nil);self:publish(r)
end
function C:admin(player,payload)
    if not adminNames[player.Name] then self:emit("Admin",{allowed=false,error="Access denied"},player);return end
    local matched={};local needle=payload.target:lower()
    for _,candidate in ipairs(Players:GetPlayers()) do
        if candidate.Name:lower()==needle then matched={candidate};break end
        if candidate.Name:lower():sub(1,#needle)==needle then matched[#matched+1]=candidate end
    end
    if #matched~=1 then self:emit("Admin",{allowed=true,error="Username is missing or ambiguous"},player);return end
    local target=matched[1]
    if payload.command=="Kick" then target:Kick("Removed by an administrator")
    elseif payload.command=="NoRespawn" then
        self.noRespawn[target]=true
        if target.Character then self:remove(target.Character);target.Character:Destroy() end
    elseif payload.command=="Kill" then
        local record=self.players[target];if record then record.humanoid.Health=0 end
    end
end
function C:request(player,id,payload)
    local gate=self.gates[player]
    if not gate then gate={tokens=30,at=timeNow()};self.gates[player]=gate end
    if not Policy.consume(gate,timeNow(),30,15) then return end
    if type(id)~="string" or #id~=12 then return end
    local index=self.protocol.config.actions[id]
    local action=index and actionNames[index]
    local r=self.players[player]
    if not action or not Policy.request(self:view(r),action,payload,timeNow()) then return end
    if action=="Gender" then
        player:SetAttribute("Gender",payload);if r then self:publish(r) end
    elseif action=="Admin" then self:admin(player,payload)
    elseif action=="Vote" then if self.voting then self.voting:vote(player,payload) end
    elseif action=="SpawnDummy" then if self.world then self.world:dummy(player,payload) end
    elseif action=="SecretDoor" then if self.world then self.world:secretDoor(player) end
    elseif action=="PairSpeed" then self:pairSpeed(r)
    elseif action=="Swing" then self:swing(r)
    elseif action=="Dash" then self:dash(r,payload)
    elseif action=="Equip" then self:equip(r,payload)
    elseif action=="Emote" then self:emote(r,payload)
    elseif action=="Drop" then self:drop(r)
    elseif action=="GetUp" then
        if timeNow()<r.nextGetUp then return end
        r.nextGetUp=timeNow()+0.07;r.getUpCount=math.min(20,r.getUpCount+1)
        if r.getUpCount>=20 then
            r.downed=false;r.getUpCount=0;self:setRagdoll(r,false);self:stopAnimation(r);self:sound(r,"audio/FlashSFX")
        end
        self:publish(r)
    end
end
function C:getSnapshot(player)
    local now=timeNow();local gate=self.snapshotGates[player]
    if gate and now-gate.at<0.5 and gate.value then gate.value.clockTime=now;return gate.value end
    local result={version=self.protocol.config.version,buildId=self.protocol.config.buildId,serverTime=now,clockTime=now,ready=self.ready,states={},
        voting=self.voting and self.voting:state(),weather=self.world and self.world:weatherState(),admin={allowed=adminNames[player.Name]==true}}
    for _,record in pairs(self.records) do result.states[#result.states+1]=self:public(record) end
    self.snapshotGates[player]={at=now,value=result}
    return result
end
function C:tick(now)
    local links={}
    for _,r in pairs(self.records) do
        if r.interaction then links[r.interaction]=true end
        self:updatePrompts(r)
        if self:alive(r) then
            if r.awakenUntil and now>=r.awakenUntil then
                r.awakenUntil=nil;r.busy=false;r.iframes=false;self:stopAnimation(r);self:publish(r)
            end
            if r.stunUntil>0 and now>=r.stunUntil then r.stunUntil=0;self:publish(r) end
            if r.wallUntil and now>=r.wallUntil then
                r.wallUntil=nil;r.wallBounce=false;r.busy=false;r.root.Anchored=false;r.ragdollUntil=0
                self:stopAnimation(r);owner(r.root,r.player);self:publish(r)
            end
            if r.ragdolled and not r.downed and not r.busy and now>=r.ragdollUntil then self:setRagdoll(r,false);self:publish(r) end
            if r.dashAt and now>=r.dashAt and not r.dashBody then
                local body=Instance.new("BodyVelocity");body.Name="DashForce";body.MaxForce=Vector3.new(30000,0,30000)
                body.Velocity=r.dashDirection*(r.dashDistance/0.3);body.Parent=r.root;r.dashBody=body
            end
            if r.dashUntil and now>=r.dashUntil then
                if r.dashBody then r.dashBody:Destroy();r.dashBody=nil end
                r.dashAt=nil;r.dashUntil=nil;r.dashing=false;owner(r.root,not r.carrying and r.player or nil);self:publish(r)
            end
            if r.emoting and Vector3.new(r.root.Velocity.X,0,r.root.Velocity.Z).Magnitude>1 then self:stopAnimation(r);self:publish(r)
            elseif r.animationExpires and now>=r.animationExpires then self:stopAnimation(r);self:publish(r) end
            if now>=r.regenAt then
                r.regenAt=now+1
                local rate=r.player and (r.awakened and 1/25 or 1/40) or 1/100
                if r.humanoid.Health<r.humanoid.MaxHealth then r.humanoid.Health=math.min(r.humanoid.MaxHealth,r.humanoid.Health+r.humanoid.MaxHealth*rate) end
            end
            for i=#r.attacks,1,-1 do
                local attack=r.attacks[i]
                if now>=attack.ends or r.downed or r.busy or r.ragdolled or now<r.stunUntil or attack.weapon~=r.weapon then
                    table.remove(r.attacks,i);self:publish(r)
                else
                    local frame=r.root.CFrame*attack.move.offset
                    if now>=attack.nextDraw then
                        attack.nextDraw=now+0.05
                        self:emit("Effect",{key="combat/Hitbox",character=r.character,cframe=frame,size=attack.move.size,duration=0.06,phase=now>=attack.activeAt and "active" or "startup"})
                    end
                    if now>=attack.activeAt then
                        for target,v in pairs(self.records) do
                            if target~=r.character and not attack.hit[target] and self:alive(v) and not v.iframes
                                and (r.root.Position-v.root.Position).Magnitude<12 and Hits.character(frame,attack.move.size,target) then
                                attack.hit[target]=true;self:damage(r,v,attack.move,false)
                            end
                        end
                    end
                end
            end
        end
    end
    for link in pairs(links) do if link.pair then self:advancePair(link,now) else self:advanceExecution(link,now) end end
    for player,group in pairs(self.holds) do
        for prompt,h in pairs(group) do if now-h.started>math.max(2,prompt.HoldDuration+1) then group[prompt]=nil end end
        if not next(group) then self.holds[player]=nil end
    end
end
function C:bindPlayer(player)
    if player:FindFirstChild("leaderstats")==nil then
        local stats=Instance.new("Folder");stats.Name="leaderstats";stats.Parent=player
        for _,name in ipairs({"Kills","Killstreak","Completions"}) do local v=Instance.new("IntValue");v.Name=name;v.Parent=stats end
    end
    local function added(character)
        if self.noRespawn[player] then character:Destroy();return end
        if self.players[player] then self:remove(self.players[player].character) end
        player.leaderstats.Killstreak.Value=0
        coroutine.wrap(function()
            local deadline=timeNow()+10
            repeat
                if player.Character~=character or not player.Parent or not character.Parent then return end
                if character:FindFirstChildOfClass("Humanoid") and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Torso") then
                    local humanoid=character:FindFirstChildOfClass("Humanoid")
                    local initialRoot=character:FindFirstChild("HumanoidRootPart")
                    -- ApplyDescription can yield and rebuild the neck. Stage the
                    -- original body on its map before allowing either operation.
                    humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
                    initialRoot.Anchored=true
                    local placed,spawnError
                    if self.world then placed,spawnError=self.world:spawn({root=initialRoot})
                    else spawnError="The original map is not initialized" end
                    if not placed then
                        initialRoot.Anchored=false
                        self:emit("Error",{text=spawnError},player);warn("FunCombat spawn: "..spawnError)
                        return
                    end
                    local ok,ready,why=pcall(Avatar.prepare,player,character,humanoid)
                    if not ok then why="R6 preparation failed: "..tostring(ready);ready=false end
                    if why and player.Parent then
                        self:emit("Error",{text=why},player);warn("FunCombat avatar: "..why)
                    end
                    if not player.Parent or player.Character~=character or not character.Parent then return end
                    local currentRoot=character:FindFirstChild("HumanoidRootPart")
                    if not ready or humanoid.Health<=0 then
                        if currentRoot then currentRoot.Anchored=false end
                        return
                    end
                    if currentRoot then currentRoot.Anchored=true end
                    local record,bindError=self:bind(character,player)
                    if currentRoot then currentRoot.Anchored=false end
                    if not record then self:emit("Error",{text=bindError or "R6 gameplay binding failed"},player);return end
                    if record and self.preserveStreak and self.preserveStreak[player] then
                        local streak=self.preserveStreak[player];self.preserveStreak[player]=nil
                        player.leaderstats.Killstreak.Value=streak
                        if streak>=5 then self:awaken(record) end
                    end
                    return
                end
                wait(0.05)
            until timeNow()>=deadline
            self:emit("Error",{text="R6 character was not available within 10 seconds. Set this place's Avatar Type to R6."},player)
            warn("FunCombat requires R6: "..player.Name)
        end)()
    end
    self.connections[#self.connections+1]=player.CharacterAdded:Connect(added)
    self.connections[#self.connections+1]=player.CharacterRemoving:Connect(function(character) self:remove(character) end)
    self.connections[#self.connections+1]=player.Chatted:Connect(function(message)
        local command,arg=message:match("^(%S+)%s*(%S*)")
        local allowed={spawn=true,d=true,sd=true,["/s"]=true,["/sd"]=true,["/spawn"]=true}
        if allowed[command] and (arg=="" or tonumber(arg)) then self:request(player,self.protocol.config.actionIds[10],arg~="" and tonumber(arg) or nil)
        elseif message=="/e secretdoor" then self:request(player,self.protocol.config.actionIds[11],nil) end
    end)
    if player.Character then added(player.Character) end
end
function C:start()
    self.action.OnServerEvent:Connect(function(player,id,payload) self:request(player,id,payload) end)
    self.snapshot.OnServerInvoke=function(player) return self:getSnapshot(player) end
    self.connections[#self.connections+1]=Players.PlayerAdded:Connect(function(player) self:bindPlayer(player) end)
    self.connections[#self.connections+1]=Players.PlayerRemoving:Connect(function(player)
        if self.players[player] then self:remove(self.players[player].character) end
        for character,sender in pairs(self.dummyOwners) do if sender==player then self:remove(character);character:Destroy() end end
        self.gates[player]=nil;self.snapshotGates[player]=nil;self.holds[player]=nil;self.noRespawn[player]=nil
        if self.world then self.world:playerRemoved(player) end
        if self.voting then self.voting:remove(player) end
    end)
    for _,player in ipairs(Players:GetPlayers()) do self:bindPlayer(player) end
    local dummy=workspace:FindFirstChild("DUMMY")
    if dummy then self:bind(dummy,nil) end
    self.connections[#self.connections+1]=Run.Heartbeat:Connect(function() self:tick(timeNow()) end)
    self.ready=true
end
require(script.Parent.PairSystem)(C)
return C
