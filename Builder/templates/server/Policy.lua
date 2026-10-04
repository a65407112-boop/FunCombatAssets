-- Pure validation policy. Encoded transport identifiers are resolved elsewhere.
local P = {}
local weapons = {Bat=true,Sword=true,[":3"]=true,BoyKisser=true,Maxwell=true,["Orange Cat"]=true,[""]=true}
local genders = {Male=true,Female=true,Fembxy=true}
local emotes = {wave=true,point=true,dance=true,dance1=true,dance2=true,dance3=true,laugh=true,cheer=true,
    ["1"]=true,["2"]=true,["3"]=true,["4"]=true,["5"]=true,Stop=true}
function P.finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
function P.string(v,max) return type(v)=="string" and #v>0 and #v<=max end
function P.fields(value,allowed)
    if type(value)~="table" then return false end
    local n=0
    for k in pairs(value) do n=n+1;if n>8 or not allowed[k] then return false end end
    return true
end
function P.free(s)
    return s and s.alive and not s.downed and not s.busy and not s.stunned
        and not s.ragdolled and not s.carriedBy and not s.carrying
end
function P.request(s,action,payload,now)
    if not P.finite(now) then return false end
    if action=="PairSpeed" then return payload==nil and s and s.alive and s.pairVictim~=nil and not s.pairReleasing and P.pairAdvance(s.pairPhase,s.pairMeter)~=nil end
    if action=="Gender" then return type(payload)=="string" and genders[payload]==true end
    if action=="Vote" then return P.string(payload,40) end
    if action=="Admin" then
        return P.fields(payload,{command=true,target=true}) and
            (payload.command=="Kick" or payload.command=="Kill" or payload.command=="NoRespawn")
            and P.string(payload.target,20) and payload.target:match("^[%w_]+$")~=nil
    end
    if action=="GetUp" then
        return payload==nil and s and s.alive and s.downed and s.canGetUp
            and not s.carriedBy and not s.busy and not s.stunned
            and P.finite(s.health) and P.finite(s.maxHealth) and s.health>=s.maxHealth/2
    end
    if action=="Drop" then
        return payload==nil and s and s.alive and s.carrying~=nil and not s.busy and not s.downed
    end
    if action=="Emote" and payload=="Stop" then return s and s.alive and not s.busy and not s.carrying and not s.carriedBy end
    if not P.free(s) then return false end
    if action=="Equip" then return type(payload)=="string" and weapons[payload] and now>=(s.nextEquip or 0) end
    if action=="Swing" then return payload==nil and weapons[s.weapon] and s.weapon~="" and now>=(s.nextSwing or 0) end
    if action=="Dash" then
        return weapons[s.weapon] and s.weapon~="" and now>=(s.nextDash or 0)
            and (payload==nil or P.fields(payload,{direction=true}))
    end
    if action=="Emote" then return not s.attacking and type(payload)=="string" and emotes[payload]==true end
    if action=="SpawnDummy" then return payload==nil or (P.finite(payload) and payload>=1 and payload<=1e11 and payload%1==0) end
    if action=="SecretDoor" then return payload==nil end
    return false
end
function P.interact(a,v,kind,distance,maxDistance)
    if not a or not v or a==v or a.character==v.character or not a.alive or not v.alive
        or not P.finite(distance) or distance>maxDistance or distance<0 then return false end
    if kind==6 then return not a.downed and a.pairVictim==v.character and v.pairActor==a.character and not a.pairReleasing end
    if a.downed or a.ragdolled or a.stunned or a.busy or a.carriedBy or v.busy then return false end
    if kind==3 or kind==4 then return a.carrying==v.character and v.carriedBy==a.character and v.downed end
    if kind~=1 and kind~=2 and kind~=5 then return false end
    return not a.carrying and not a.attacking and v.downed and not v.carriedBy
end
function P.pairAdvance(phase,meter)
    if not P.finite(meter) then return nil end
    local threshold=({[1]=0.28,[2]=0.62,[3]=1})[phase]
    if threshold and meter>=threshold-0.000001 then return phase+1 end
    return nil
end
function P.holdReady(h,now,duration)
    if not h or not P.finite(h.started) or now<h.started or now-h.started>math.max(2,duration+1) then return false end
    if h.ended and (h.ended-h.started<duration-0.025 or now-h.ended>0.25) then return false end
    return now-h.started>=duration-0.025
end
function P.consume(gate,now,capacity,rate)
    gate.tokens=math.min(capacity,(gate.tokens or capacity)+math.max(0,now-(gate.at or now))*rate)
    gate.at=now
    if gate.tokens<1 then return false end
    gate.tokens=gate.tokens-1
    return true
end
return P
