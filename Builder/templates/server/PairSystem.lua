-- Mechanical adaptation of the original CombatFunctions interaction state.
-- Models, audio and Pose data are supplied unchanged by the external package.
local Policy=require(script.Parent.Policy)
return function(C)
    function C:pairAnimations(link,phase)
        local a,v=link.a,link.v
        local actorGender=link.tag=="FD" and "female" or "male"
        local victimGender=link.tag=="FD" and "male" or "female"
        local suffix=tostring(phase)
        self:animation(a,actorGender.."/"..link.tag.."/"..suffix,phase~="release")
        self:animation(v,victimGender.."/"..link.tag.."/"..suffix,phase~="release")
    end
    function C:beginPair(a,v,tag,wall)
        if not a or not v or not a.player or a.interaction or v.interaction then return end
        if tag=="Wall" then
            if not wall or not wall:IsA("BasePart") or not self.world.activeMap or not wall:IsDescendantOf(self.world.activeMap)
                or not Policy.interact(self:view(a),self:view(v),4,(a.root.Position-wall.Position).Magnitude,6) then return end
            self:restoreCarry(a,v)
        elseif not Policy.interact(self:view(a),self:view(v),5,(a.root.Position-v.torso.Position).Magnitude,6) then return end
        self:cancelAttack(a);self:cancelAttack(v);self:setRagdoll(v,false)
        if tag=="Default" and a.player:GetAttribute("Gender")=="Female" then tag="FD" end
        if wall then a.root.CFrame=wall.CFrame*CFrame.new(0,0,4) end
        v.root.CFrame=a.root.CFrame*CFrame.new(0,0,tag=="FD" and 0 or -4)
        local link={pair=true,a=a,v=v,tag=tag,phase=1,nextBeat=tick()+0.8,interval=0.8,released=false,
            id=tostring(a.epoch)..":"..tostring(v.epoch)..":"..tostring(tick())}
        a.interaction,v.interaction=link,link;a.pairVictim=v;v.pairActor=a
        a.busy,v.busy=true,true;a.iframes,v.iframes=true,true
        a.root.Anchored,v.root.Anchored=true,true
        self:pairAnimations(link,1);self:sound(v,"audio/EnterFun");self:effect(v,"effects/Hits/Hearts",2)
        self:publish(a);self:publish(v)
    end
    function C:clearPair(link)
        local a,v=link.a,link.v
        a.pairVictim=nil;v.pairActor=nil
        if not link.releasing and (a.funMeter or 0)>=1 then a.funMeter=0.94 end
        self:emit("Pair",{a=a.character,v=v.character,kind="Clear",pairId=link.id})
    end
    function C:stopPair(a,v)
        local link=a.interaction
        if not link or not link.pair or link.a~=a or link.v~=v or link.releasing then return end
        self:effect(v,"effects/Hits/Hearts",2);self:sound(v,"audio/EnterFun")
        self:release(link)
    end
    function C:pairBurst(link,finish)
        self:emit("Pair",{a=link.a.character,v=link.v.character,kind="Particles",tag=link.tag,pairId=link.id,
            n1=finish and 30 or 20,n2=finish and 17 or 10})
        if link.a.player then self:emit("Pair",{kind="Hit",a=link.a.character},link.a.player) end
    end
    function C:pairSpeed(a)
        local link=a and a.interaction
        if not link or not link.pair or link.a~=a or link.released or link.releasing then return end
        local nextPhase=Policy.pairAdvance(link.phase,a.funMeter)
        if not nextPhase then return end
        link.phase=nextPhase
        self:emit("Pair",{a=a.character,v=link.v.character,kind="Phase",phase=nextPhase},a.player)
        if nextPhase<4 then
            link.interval=link.interval*0.4;link.nextBeat=tick()+link.interval
            self:pairAnimations(link,nextPhase)
        else
            link.releasing=true;link.started=tick();link.releaseAt=link.started+(link.tag=="Wall" and 5 or link.tag=="FD" and 3 or 7)
            link.bursts=link.tag=="Wall" and {2,4} or link.tag=="FD" and {2} or {3}
            a.funMeter=0
            self:pairAnimations(link,"release")
            self:sound(link.tag=="FD" and a or link.v,"audio/Release",7.5)
            self:sound(link.v,"audio/Eject");self:sound(link.v,"audio/Test4")
            a.player.leaderstats.Completions.Value=a.player.leaderstats.Completions.Value+1
            self:effect(a,"effects/LevelUp/UpCompletion",2);self:sound(a,"audio/LevelUp")
            self:pairBurst(link,true)
        end
        self:publish(a);self:publish(link.v)
    end
    function C:advancePair(link,now)
        if link.released then return end
        if not self:alive(link.a) or not self:alive(link.v) then self:release(link);return end
        if link.releasing then
            while link.bursts[1] and now-link.started>=link.bursts[1] do
                table.remove(link.bursts,1);self:pairBurst(link,true)
                self:sound(link.v,"audio/Eject");self:sound(link.v,"audio/Test4")
            end
            if now>=link.releaseAt then
                self:effect(link.a,"effects/Hits/Hearts",2);self:sound(link.v,"audio/EnterFun");self:release(link)
            end
        elseif now>=link.nextBeat then
            link.nextBeat=now+link.interval
            link.a.funMeter=math.min(1,(link.a.funMeter or 0)+0.02)
            self:pairBurst(link,false)
            self:sound(link.v,"audio/Slap"..math.random(1,3));self:sound(link.v,"audio/Test"..math.random(1,3))
            self:publish(link.a)
        end
    end
end
