local P = require("../templates/server/Policy")
local s = {alive=true,downed=false,busy=false,stunned=false,ragdolled=false,
    carrying=nil,carriedBy=nil,weapon="Bat",nextSwing=0,nextDash=0,nextEquip=0}
assert(P.finite(3) and not P.finite(0/0) and not P.finite(math.huge))
assert(P.request(s, "Swing", nil, 1))
assert(not P.request(s, "Swing", {damage=999}, 1))
s.nextSwing=2
assert(not P.request(s, "Swing", nil, 1))
s.nextSwing=0
assert(not P.request(s, "Equip", "InventedWeapon", 1))
assert(P.request(s,"Equip",":3",1))
s.downed=true
assert(not P.request(s,"Swing",nil,3))
s.health=49;s.maxHealth=100;s.canGetUp=true
assert(not P.request(s,"GetUp",nil,3))
s.health=50
assert(P.request(s,"GetUp",nil,3))
s.carriedBy={}
assert(not P.request(s,"GetUp",nil,3))
s.carriedBy=nil;s.downed=false
assert(not P.request(s,"Gender",{value="Male"},3))
assert(P.request(s,"Gender","Male",3))
assert(not P.request(s,"SpawnDummy",0/0,3))
assert(not P.request(s,"Admin",{command="Kill",target=""},3))
assert(not P.request(s,"Admin",{command="Kill",target="Bob",huge={}},3))
assert(P.request(s,"Admin",{command="Kill",target="Bob"},3))
local actor={alive=true,character={},downed=false,busy=false,stunned=false,ragdolled=false}
local victim={alive=true,character={},downed=true,busy=false}
assert(P.interact(actor,victim,1,5,6))
assert(not P.interact(actor,victim,1,7,6))
assert(not P.interact(actor,victim,1,0/0,6))
actor.carrying=victim.character;victim.carriedBy=actor.character
assert(P.interact(actor,victim,3,5,6))
assert(P.interact(actor,victim,4,5,6))
assert(not P.interact(actor,victim,2,5,6))
victim.carriedBy={}
assert(not P.interact(actor,victim,3,5,6))
assert(not P.holdReady(nil,1,0.3))
assert(not P.holdReady({started=0.9},1,0.3))
assert(P.holdReady({started=0.6},1,0.3))
assert(not P.holdReady({started=-10},1,0.3))
assert(not P.holdReady({started=0.5,ended=0.55},1,0.3))
assert(P.holdReady({started=0.5,ended=0.81},0.82,0.3))
assert(not P.holdReady({started=0.5,ended=0.81},1.5,0.3))
local gate={tokens=2,at=0}
assert(P.consume(gate,0,2,1));assert(P.consume(gate,0,2,1))
assert(not P.consume(gate,0,2,1));assert(P.consume(gate,1,2,1))
actor.carrying=nil;victim.carriedBy=nil
assert(P.interact(actor,victim,5,5,6))
actor.busy=true;victim.busy=true;actor.pairVictim=victim.character;victim.pairActor=actor.character
assert(P.interact(actor,victim,6,5,6))
victim.pairActor={}
assert(not P.interact(actor,victim,6,5,6))
assert(P.pairAdvance(1,0.26)==nil)
assert(P.pairAdvance(1,0.28)==2)
assert(P.pairAdvance(2,0.6)==nil)
assert(P.pairAdvance(2,0.62)==3)
assert(P.pairAdvance(3,1)==4)
assert(P.pairAdvance(4,1)==nil)
assert(P.pairAdvance(1,0/0)==nil)
local pair={alive=true,pairVictim={},pairPhase=1,pairMeter=0.28}
assert(P.request(pair,"PairSpeed",nil,1))
assert(not P.request(pair,"PairSpeed",{phase=4},1))
print("Policy: combat, holds, ownership, rate limiting and pair phase checks passed")
