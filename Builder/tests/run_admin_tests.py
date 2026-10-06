"""Execute real admin/game modules; double only Roblox APIs and the hosted asset boundary."""
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
local _G={}
local warnings={}
local function warn(message) warnings[#warnings+1]=message end
local jobs,serial={},0
local function enqueue(at,fn,args)
    serial+=1;local entry={at=at,id=serial,fn=fn,args=args or {},cancelled=false};jobs[#jobs+1]=entry;return entry
end
local task={}
function task.delay(seconds,fn,...) return enqueue(now+seconds,fn,{...}) end
function task.spawn(fn,...)
    local co=if type(fn)=='thread' then fn else coroutine.create(fn)
    local args={...}
    enqueue(now,function() local ok,why=coroutine.resume(co,unpack(args));assert(ok,why) end)
    return co
end
function task.cancel(co) if type(co)=='table' then co.cancelled=true end end
local function advance(seconds)
    local ending=now+seconds;local guard=0
    repeat
        local best,index
        for i,j in ipairs(jobs) do
            if not j.cancelled and j.at<=ending and (not best or j.at<best.at or (j.at==best.at and j.id<best.id)) then best,index=j,i end
        end
        if not best then break end
        table.remove(jobs,index);now=best.at;best.fn(unpack(best.args));guard+=1;assert(guard<1000,'Unbounded admin scheduler')
    until false
    now=ending
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:IsDescendantOf(parent) local cur=self.Parent;while cur do if cur==parent then return true end;cur=cur.Parent end;return false end
function methods:GetFullName() return self.Name end
function methods:Invoke(...) return self.OnInvoke(...) end
function methods:Kick(reason) self.kicked=reason end
local originalClone=methods.Clone
function methods:Clone()
    local why=self:GetAttribute('FixtureCloneError');if why then error(why) end
    return originalClone(self)
end
Enum.CreatorType={User=0,Group=1}
Enum.HumanoidRigType={R6=0,R15=1}
Enum.HumanoidHealthDisplayType={AlwaysOff=0}
local Players,Groups,ServerScripts,ServerStorage
local groupBehavior,groupThread,assetBehavior,assetThread,assetCalls,native
local modules={}
local script={Parent={Policy='Policy',Avatar='Avatar',Ragdoll='Ragdoll',HitDetection='HitDetection',PairSystem='PairSystem',
    CombatServer='CombatServer',WorldData='WorldData',MoveData='MoveData',AnimationTiming='AnimationTiming',AdminAccess='AdminAccess'}}
local function require(value)
    if type(value)=='number' then
        assetCalls[#assetCalls+1]=value
        assert(value==1868400649,'Loader requested an unverified external dependency')
        assert(_G.KAU==true,'Original legacy selector was not enabled')
        assert(native.Parent==ServerScripts and native.Name=="Kohl's Admin Infinite",'Real KAI cannot discover the native Credit Script')
        assert(native.Disabled==true,'Native Credit executed a second unbounded require')
        assert(native:FindFirstChild('Settings') and native:FindFirstChild('Custom Commands'),'Native configuration was lost')
        if assetBehavior=='error' then error('Asset is not trusted for this place: 1868400649') end
        if assetBehavior=='pending' then assetThread=coroutine.running();coroutine.yield() end
        return true
    end
    return assert(modules[value],'Unexpected local dependency '..tostring(value))
end
local function fixture(kind,id)
    jobs={};now=100;_G.KAU=nil;serial=0;assetCalls={};assetThread=nil;groupThread=nil;assetBehavior='success';groupBehavior='success'
    Players=Players or node('Players','Players');Players.children={};Players.PlayerAdded=signal();Players.PlayerRemoving=signal()
    function Players:GetPlayers() return self:GetChildren() end
    function Players:GetNameFromUserIdAsync(userId) return 'Avatar'..userId end
    function Players:GetPlayerFromCharacter() return nil end
    function Players:GetHumanoidDescriptionFromUserIdAsync(userId)
        local desc=node('HumanoidDescription');desc.Head=0;desc.Face=777;desc.MoodAnimation=88;desc.userId=userId;return desc
    end
    Groups={GetGroupInfoAsync=function(_,groupId)
        assert(groupId==9876,'Creator group identity changed')
        if groupBehavior=='error' then error('HTTP 403: group 9876 owner unavailable') end
        if groupBehavior=='pending' then groupThread=coroutine.running();coroutine.yield() end
        if groupBehavior=='malformed' then return {Owner=nil} end
        return {Id=9876,Name='Creator group',Owner={Id=2468,Name='ActualOwner'},MemberCount=12,IsPublic=true}
    end}
    ServerScripts=node('ServerScriptService');ServerStorage=node('ServerStorage');workspace=node('Workspace')
    game.CreatorType=kind or Enum.CreatorType.User;game.CreatorId=id or 1357;game.PrivateServerOwnerId=9753
    game.GetService=function(_,name)
        if name=='Players' then return Players elseif name=='GroupService' then return Groups
        elseif name=='ServerScriptService' then return ServerScripts elseif name=='ServerStorage' then return ServerStorage
        elseif name=='RunService' then return {IsStudio=function() return false end,Heartbeat=signal()} elseif name=='Debris' then return {} end
        error('Unexpected engine service '..name)
    end
end
local function player(id,name)
    local p=node('Player',name or 'Player'..id);p.UserId=id;p.Parent=Players
    p.leaderstats={Kills={Value=0},Killstreak={Value=0},Completions={Value=0}}
    Players.PlayerAdded:fire(p);return p
end
local function nativeLoader()
    native=node('Script','Credit');native.Disabled=true;native.Parent=ServerStorage
    local settings=node('ModuleScript','Settings');settings.Parent=native
    local custom=node('ModuleScript','Custom Commands');custom.Parent=native
    return native
end
local function rig(name)
    local c=node('Model',name or 'Rig');local root=node('Part','HumanoidRootPart');root.Parent=c;root.Anchored=false
    local torso=node('Part','Torso');torso.Parent=c;local head=node('Part','Head');head.Parent=c
    local hum=node('Humanoid');hum.Parent=c;hum.HealthChanged=signal();hum.Died=signal();hum.WalkSpeed=16;hum.JumpPower=50;hum.JumpHeight=7.2;hum.MaxHealth=100
    function hum:ApplyDescriptionAsync(desc) self.appliedUserId=desc.userId end
    for _,part in ipairs({root,torso,head}) do part.Touched=signal();function part:SetNetworkOwner(owner) self.networkOwner=owner end end
    return c
end
local function dummyWorld(owner)
    local templates=node('Folder','Templates');templates.Prompts=node('Folder','Prompts')
    templates.DummyRig=rig('DummyRig')
    local net=node('Folder','Protocol');for _,name in ipairs({'Action','Event','Snapshot'}) do local x=node('RemoteEvent',name);x.Parent=net
        function x:FireAllClients() end;function x:FireClient() end
    end
    local config={version=4,buildId='admin-test',names={'Protocol','Action','Event','Snapshot'},prompts={},events={}}
    for i=1,14 do config.events[i]='Event'..i end
    local combat=modules.CombatServer.new({folder=net,config=config},templates)
    local original=rig('OwnerCharacter');original.Parent=workspace;owner.Character=original
    local record=assert(combat:bind(original,owner));record.attacks={};record.stunUntil=0
    local configuration=node('Folder','Configuration');configuration.Parent=workspace
    local enabled=node('BoolValue','AllowDummys');enabled.Value=true;enabled.Parent=configuration
    local world=setmetatable({combat=combat,templates=templates,dummyCooldown={},weather={name='Sunny',revision=1}},modules.World);combat.world=world
    return world,combat
end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Admin: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
'''
for name in ['Policy', 'Avatar', 'Ragdoll', 'HitDetection', 'PairSystem', 'AdminAccess', 'CombatServer', 'World', 'KohlAdmin']:
    path = ROOT / 'Builder/templates/server' / (name + '.lua')
    source = path.read_text() if path.is_file() else 'return {}'
    code += '\nmodules[' + repr(name) + ']=(function()\n' + source + '\nend)()\n' if name not in ['World', 'CombatServer'] else ''
    if name == 'CombatServer':
        code += '\nmodules.MoveData={};modules.AnimationTiming={}\nmodules.CombatServer=(function()\n' + source + '\nend)()\n'
    if name == 'World':
        code += '\nmodules.WorldData={initialMap="Map"}\nmodules.World=(function()\n' + source + '\nend)()\n'

# Engine services exist before the production modules resolve GetService.
marker = "\nmodules['Policy']="
code = code.replace(marker, "\nfixture()" + marker, 1)
code += r'''
check('published user creator is authorized before any asynchronous work',function()
    fixture();local p=player(1357);local outsider=player(42)
    local a=modules.AdminAccess.new()
    assert(a:allowed(p),'The actual published creator has no native admin access')
    assert(not a:allowed(outsider),'An ordinary player received admin')
    assert(p:GetAttribute('FunCombatAdminAllowed')==true and a:status().ownerUserId==1357,'Creator grant was not exposed to native player state')
end)
check('legacy usernames, private hosts and first joiners receive no grant',function()
    fixture();local early=player(42,'GuardianWorld');local host=player(9753)
    local a=modules.AdminAccess.new();assert(not a:allowed(early) and not a:allowed(host),'Unrelated identity received admin')
end)
check('unpublished or invalid creator identity fails closed with diagnostics',function()
    fixture(Enum.CreatorType.User,0);local p=player(42);local a=modules.AdminAccess.new()
    assert(not a:allowed(p) and a:status().state=='error' and a:status().error:find('CreatorId=0'),'Missing publication silently granted admin')
end)
check('group owner grant refreshes players who joined before the query completed',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='pending';local p=player(2468);local member=player(9876);local changed={}
    local a=modules.AdminAccess.new(function(who,allowed,state) changed[who]={allowed=allowed,state=state.state} end,2)
    advance(0);assert(not a:allowed(p) and changed[p].allowed==false,'Pending group resolution granted admin')
    assert(coroutine.resume(groupThread));assert(a:allowed(p) and not a:allowed(member),'Group ID or membership was mistaken for its owner')
    assert(p:GetAttribute('FunCombatAdminAllowed')==true and changed[p].allowed==true and changed[p].state=='ready','Early join never learned the creator grant')
    local later=player(2468,'OwnerRejoined');assert(a:allowed(later) and later:GetAttribute('FunCombatAdminAllowed')==true,'A late owner join lost access')
end)
check('group service error preserves its exact failure and denies everyone',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='error';local p=player(2468);local a=modules.AdminAccess.new(nil,2);advance(0)
    assert(not a:allowed(p) and a:status().state=='error' and a:status().error:find('HTTP 403: group 9876 owner unavailable',1,true),'Group error was hidden or bypassed')
end)
check('malformed group ownership response fails closed',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='malformed';local p=player(2468);local a=modules.AdminAccess.new(nil,2);advance(0)
    assert(not a:allowed(p) and a:status().state=='error' and a:status().error:find('owner'),'Missing owner response granted members')
end)
check('bounded group timeout and late result never grant admin',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='pending';local p=player(2468);local a=modules.AdminAccess.new(nil,2);advance(2.1)
    assert(a:status().state=='timeout' and not a:allowed(p),'Group query did not fail closed at its deadline')
    assert(coroutine.resume(groupThread));assert(a:status().state=='timeout' and not a:allowed(p),'Late group lookup changed a timed-out authorization')
end)
check('native access excludes departed players and spoofed tables',function()
    fixture();local p=player(1357);local a=modules.AdminAccess.new();p.Parent=nil
    assert(not a:allowed(p) and not a:allowed({UserId=1357,Parent=Players}),'A detached or client-style identity was authorized')
end)
check('configured numeric owner above 32 bits and the actual creator both receive distinct grants',function()
    fixture();local configured=player(11556197791);local creator=player(1357);local outsider=player(42)
    local a=modules.AdminAccess.new(nil,2,11556197791)
    assert(a:allowed(configured) and a:allowed(creator) and not a:allowed(outsider),'The configured account or actual creator lost access')
    assert(a:grantSource(configured)=='configuredOwner' and a:grantSource(creator)=='publishedCreator' and a:grantSource(outsider)==nil,'Grant diagnostics identify the wrong authority')
    local status=a:status()
    assert(status.configuredOwnerUserId==11556197791 and status.ownerUserId==1357 and status.configError==nil,'Configured identity replaced automatic ownership')
    assert(configured:GetAttribute('FunCombatConfiguredOwnerUserId')==11556197791 and configured:GetAttribute('FunCombatAdminSource')=='configuredOwner','The configured grant is absent from native player diagnostics')
    assert(creator:GetAttribute('FunCombatAdminSource')=='publishedCreator' and outsider:GetAttribute('FunCombatAdminSource')=='','Native grant source is misleading')
end)
check('matching configured owner preserves actual published creator authority',function()
    fixture(Enum.CreatorType.User,11556197791);local owner=player(11556197791)
    local a=modules.AdminAccess.new(nil,2,11556197791)
    assert(a:allowed(owner) and a:grantSource(owner)=='publishedCreator','An explicit duplicate downgraded true creator authority')
    assert(a:status().ownerUserId==11556197791 and a:status().configuredOwnerUserId==11556197791,'Matching owner diagnostics were lost')
end)
check('absent or invalid configured IDs never grant strangers or disable the real creator',function()
    fixture();local creator=player(1357);local outsider=player(11556197791)
    local absent=modules.AdminAccess.new()
    assert(absent:allowed(creator) and not absent:allowed(outsider) and absent:status().configuredOwnerUserId==nil and absent:status().configError==nil,'Absent config creates an implicit grant')
    assert(outsider:GetAttribute('FunCombatConfiguredOwnerUserId')==0,'Missing configured owner has no unambiguous native diagnostic')
    absent:destroy()
    for _,bad in ipairs({0,-1,1.5,0/0,math.huge,9007199254740992,'11556197791',true,{ownerUserId=11556197791}}) do
        local warningCount=#warnings;local a=modules.AdminAccess.new(nil,2,bad)
        assert(a:allowed(creator) and not a:allowed(outsider),'Invalid explicit config changed creator authorization')
        assert(a:status().configuredOwnerUserId==nil and type(a:status().configError)=='string' and #warnings>warningCount,'Invalid owner config was not reported independently')
        a:destroy()
    end
end)
check('configured owner is immediate during a group query while a genuine group owner still resolves',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='pending'
    local configured=player(11556197791);local creator=player(2468);local member=player(9876);local changed={}
    local a=modules.AdminAccess.new(function(who,allowed,status) changed[who]={allowed=allowed,status=status} end,2,11556197791)
    assert(a:allowed(configured) and not a:allowed(creator) and not a:allowed(member) and a:status().state=='pending','Pending creator query blocks explicit owner or grants an unknown identity')
    assert(changed[configured].allowed and changed[configured].status.configuredOwnerUserId==11556197791,'Early configured owner never received the native callback')
    local later=player(11556197791,'ConfiguredOwnerRejoined');assert(a:allowed(later) and later:GetAttribute('FunCombatAdminSource')=='configuredOwner','Late configured owner join was denied')
    advance(0);assert(coroutine.resume(groupThread))
    assert(a:allowed(configured) and a:allowed(creator) and not a:allowed(member),'Explicit config replaced actual group ownership')
    assert(a:grantSource(creator)=='publishedCreator' and creator:GetAttribute('FunCombatAdminSource')=='publishedCreator','Group grant did not refresh diagnostics')
end)
check('group lookup failure retains only the configured grant and exact creator failure',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='error'
    local configured=player(11556197791);local creator=player(2468);local member=player(9876)
    local a=modules.AdminAccess.new(nil,2,11556197791);advance(0)
    assert(a:allowed(configured) and not a:allowed(creator) and not a:allowed(member),'Failed group query granted unknown players or revoked explicit owner')
    assert(a:status().state=='error' and a:status().error:find('HTTP 403: group 9876 owner unavailable',1,true),'Explicit grant concealed creator lookup failure')
    assert(configured:GetAttribute('FunCombatAdminAllowed')==true and configured:GetAttribute('FunCombatAdminState')=='error','Creator state and configured grant became conflated')
end)
check('group timeout and late result retain only the configured owner grant',function()
    fixture(Enum.CreatorType.Group,9876);groupBehavior='pending';local configured=player(11556197791);local creator=player(2468)
    local a=modules.AdminAccess.new(nil,2,11556197791);advance(2.1)
    assert(a:status().state=='timeout' and a:allowed(configured) and not a:allowed(creator),'Timeout mishandled the independent configured grant')
    assert(coroutine.resume(groupThread))
    assert(a:status().state=='timeout' and a:allowed(configured) and not a:allowed(creator),'Late group result changed timed-out creator authorization')
end)
check('an unpublished CreatorId zero retains only the explicitly configured owner',function()
    fixture(Enum.CreatorType.User,0);local configured=player(11556197791);local outsider=player(42)
    local a=modules.AdminAccess.new(nil,2,11556197791)
    assert(a:allowed(configured) and not a:allowed(outsider),'Unpublished creator identity overrode explicit numeric owner')
    assert(a:status().state=='error' and a:status().error:find('CreatorId=0') and a:status().ownerUserId==nil,'Explicit grant disguised unavailable publication identity')
end)
check('configured access rejects departed spoofed and destroyed identities',function()
    fixture();local configured=player(11556197791);local creator=player(1357);local a=modules.AdminAccess.new(nil,2,11556197791)
    assert(a:allowed(configured),'Configured owner never received access')
    assert(not a:allowed({UserId=11556197791,Parent=Players}) and a:grantSource({UserId=11556197791,Parent=Players})==nil,'Spoofed configured identity was authorized')
    local other=node('Folder','SpoofedOwner');other.UserId=11556197791;other.Parent=Players;assert(not a:allowed(other),'A non-Player Instance received configured access')
    other.Parent=nil;configured.Parent=nil;assert(not a:allowed(configured),'Departed configured Player retained access')
    configured.Parent=Players;a:destroy()
    assert(not a:allowed(configured) and not a:allowed(creator) and a:grantSource(configured)==nil,'Destroyed access retained an owner grant')
    assert(configured:GetAttribute('FunCombatAdminAllowed')==false and configured:GetAttribute('FunCombatAdminSource')=='','Destroyed native diagnostics still advertise access')
end)
check('actual native snapshot and admin action authorize the exact configured owner',function()
    fixture();local configured=player(11556197791);local target=player(42,'Target');local a=modules.AdminAccess.new(nil,2,11556197791)
    local _,combat=dummyWorld(configured);combat.adminAccess=a
    local snapshot=combat:getSnapshot(configured)
    assert(snapshot.admin.allowed==true and snapshot.admin.creator.configuredOwnerUserId==11556197791,'Native admin consumer ignored configured identity')
    combat:admin(configured,{command='Kick',target='Target'});assert(target.kicked=='Removed by an administrator','Configured native owner action was rejected')
end)
check('actual native snapshot and admin action grant the injected published user creator',function()
    fixture();local owner=player(1357,'PublishedCreator');local target=player(42,'Target')
    local a=modules.AdminAccess.new();local _,combat=dummyWorld(owner);combat.adminAccess=a
    assert(combat:getSnapshot(owner).admin.allowed==true,'Native creator panel still uses the old name allowlist')
    combat:admin(owner,{command='Kick',target='Target'})
    assert(target.kicked=='Removed by an administrator','A valid native creator admin action was rejected')
end)
check('actual native snapshot and admin action deny legacy names despite their previous allowlist',function()
    fixture();local owner=player(1357,'PublishedCreator');local oldAdmin=player(53,'GuardianWorld');local target=player(42,'Target')
    local a=modules.AdminAccess.new();local _,combat=dummyWorld(owner);combat.adminAccess=a
    assert(combat:getSnapshot(oldAdmin).admin.allowed==false,'Legacy username still opens native admin controls')
    combat:admin(oldAdmin,{command='Kick',target='Target'})
    assert(target.kicked==nil,'Old source username bypassed the creator check at the action boundary')
end)
check('actual native snapshot and admin action fail closed when access was not injected',function()
    fixture();local owner=player(1357,'GuardianWorld');local target=player(42,'Target');local _,combat=dummyWorld(owner)
    combat.adminAccess=nil
    assert(combat:getSnapshot(owner).admin.allowed==false,'Missing access service defaulted the creator panel to allowed')
    combat:admin(owner,{command='Kick',target='Target'})
    assert(target.kicked==nil,'Missing access service allowed an original username action')
end)
check('actual native group-owner snapshot and admin action deny ordinary group members',function()
    fixture(Enum.CreatorType.Group,9876);local owner=player(2468,'GroupOwner');local member=player(53,'GroupMember');local target=player(42,'Target')
    local a=modules.AdminAccess.new();advance(0);local _,combat=dummyWorld(owner);combat.adminAccess=a
    assert(combat:getSnapshot(owner).admin.allowed==true and combat:getSnapshot(member).admin.allowed==false,'Native group-owner controls have the wrong identity')
    combat:admin(member,{command='Kick',target='Target'});assert(target.kicked==nil,'Ordinary group member performed native admin action')
    combat:admin(owner,{command='Kick',target='Target'});assert(target.kicked=='Removed by an administrator','Actual group creator could not act')
end)
check('trusted loader uses the original dependency and native legacy hierarchy',function()
    fixture();local p=player(1357);local a=modules.AdminAccess.new();local world=dummyWorld(p)
    local h=modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    assert(h:status().state=='ready' and #assetCalls==1 and assetCalls[1]==1868400649,'Full genuine Kohl admin did not load once')
    assert(native:FindFirstChild('FunCombatDummy'):IsA('BindableFunction'),'Integrated dummy has no server-only API')
end)
check('loader errors include the exact hosted permission failure',function()
    fixture();local a=modules.AdminAccess.new();assetBehavior='error';local h=modules.KohlAdmin.start(nativeLoader(),a,{},2);advance(0)
    assert(h:status().state=='error' and h:status().error:find('Asset is not trusted for this place: 1868400649',1,true),'Hosted require failure was hidden')
end)
check('loader reserves the legacy selector before another startup can race it',function()
    fixture();local a=modules.AdminAccess.new();local credit=nativeLoader()
    local first=modules.KohlAdmin.start(credit,a,{},2);local second=modules.KohlAdmin.start(credit,a,{},2);advance(0)
    assert(first:status().state=='ready' and second:status().state=='error' and #assetCalls==1,'Concurrent starts duplicated the real hosted admin')
end)
check('missing native settings fail before any external code is required',function()
    fixture();local a=modules.AdminAccess.new();local credit=nativeLoader();credit:FindFirstChild('Settings'):Destroy()
    local h=modules.KohlAdmin.start(credit,a,{},2);advance(0)
    assert(h:status().state=='error' and h:status().error:find('Settings') and #assetCalls==0,'Loader started without its native configuration')
end)
check('hosted require has a deadline without blocking game initialization',function()
    fixture();local a=modules.AdminAccess.new();assetBehavior='pending';local h=modules.KohlAdmin.start(nativeLoader(),a,{},2);advance(2.1)
    assert(h:status().state=='timeout' and h:status().error:find('1868400649'),'A slow hosted module left startup pending forever')
    assert(coroutine.resume(assetThread));assert(h:status().state=='timeout','Late require incorrectly reported an on-time load')
end)
check('unrelated group member cannot invoke the server dummy API',function()
    fixture(Enum.CreatorType.Group,9876);local owner=player(2468);local outsider=player(53);local a=modules.AdminAccess.new();advance(0)
    local world,combat=dummyWorld(owner);local h=modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    local ok,why=native:FindFirstChild('FunCombatDummy'):Invoke(outsider)
    assert(ok==false and why:find('creator') and next(combat.dummyOwners)==nil,'Nonowner spawned a combat dummy')
end)
check('owner dummy API binds the original rig to real combat state',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    local ok,why=native:FindFirstChild('FunCombatDummy'):Invoke(owner)
    local model=next(combat.dummyOwners);assert(ok==true and model and combat.records[model] and combat.dummyOwners[model]==owner,why or 'Dummy bypassed combat binding')
    assert(model:FindFirstChild('HumanoidRootPart').CFrame[3]==-5,'Dummy did not use the original in-front spawn')
end)
check('avatar dummy API uses the original appearance preparation',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    local ok,why=native:FindFirstChild('FunCombatDummy'):Invoke(owner,261)
    local model=next(combat.dummyOwners);assert(ok==true and model and combat.records[model],why)
    assert(model:FindFirstChildOfClass('Humanoid').appliedUserId==261,'Avatar dummy bypassed real Avatar.prepareDummy')
end)
check('dummy API rejects nonpositive fractional nonfinite or oversized user IDs',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0);local bridge=native:FindFirstChild('FunCombatDummy')
    for _,bad in ipairs({0,-1,1.5,0/0,math.huge,1e12,'261',true}) do
        local ok,why=bridge:Invoke(owner,bad);assert(ok==false and type(why)=='string','Invalid avatar ID reached world spawning')
    end
    assert(next(combat.dummyOwners)==nil,'Malformed user ID created a dummy')
end)
check('dummy API retains game cooldown and per-owner limit with exact feedback',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0);local bridge=native:FindFirstChild('FunCombatDummy')
    assert(bridge:Invoke(owner)==true);local ok,why=bridge:Invoke(owner);assert(ok==false and why:find('cooldown'),'Admin bypassed original dummy cooldown')
    for i=2,4 do advance(3.1);assert(bridge:Invoke(owner)==true) end
    advance(3.1);ok,why=bridge:Invoke(owner);assert(ok==false and why:find('limit'),'Admin bypassed original dummy limit')
    local count=0;for _ in pairs(combat.dummyOwners) do count+=1 end;assert(count==4,'More than four dummies were created')
end)
check('admin dummy still honors the original configuration and free combat state',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0);local bridge=native:FindFirstChild('FunCombatDummy')
    local allowed=workspace:FindFirstChild('Configuration'):FindFirstChild('AllowDummys');allowed.Value=false
    local ok,why=bridge:Invoke(owner);assert(ok==false and type(why)=='string' and #why>0,'Disabled dummy setting was bypassed or silent')
    allowed.Value=true;combat.players[owner].busy=true
    ok,why=bridge:Invoke(owner);assert(ok==false and type(why)=='string' and #why>0,'Busy combat state was bypassed or silent')
    assert(next(combat.dummyOwners)==nil,'Blocked game state produced a dummy')
end)
check('real classic custom command forwards an optional avatar ID and exact creator rejection',function()
    fixture();local owner=player(1357);local outsider=player(42);local a=modules.AdminAccess.new();local world,combat=dummyWorld(owner)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    assert(type(modules.KohlAdmin.commands)=='function','Classic dummy command implementation is missing')
    local definitions=modules.KohlAdmin.commands(native:FindFirstChild('FunCombatDummy'))
    local command
    for _,definition in ipairs(definitions) do for _,alias in ipairs(definition[1]) do if alias=='dummy' then command=definition end end end
    assert(command and command[3]==5 and command[4][1]=='number/','Native KAI cannot authorize/parse an Owner-rank dummy command')
    local ok,why=pcall(command[5],outsider,{261});assert(not ok and why:find('published game creator or configured owner'),'Custom command concealed the authorization error')
    command[5](owner,{261});local model=next(combat.dummyOwners)
    assert(model and combat.records[model] and model:FindFirstChildOfClass('Humanoid').appliedUserId==261,'Native custom command bypassed the original avatar dummy pathway')
end)
check('configured native Owner rank five invokes the real custom dummy command',function()
    fixture(Enum.CreatorType.User,0);local configured=player(11556197791);local outsider=player(42)
    local a=modules.AdminAccess.new(nil,2,11556197791);local world,combat=dummyWorld(configured)
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    local command=modules.KohlAdmin.commands(native:FindFirstChild('FunCombatDummy'))[1]
    assert(command[3]==5 and 5>=command[3],'Genuine configured Owner power cannot pass the native command schema')
    local ok,why=pcall(command[5],outsider,{11556197791});assert(not ok and why:find('configured owner'),'Minimum power change removed the exact server permission gate')
    command[5](configured,{11556197791});local model=next(combat.dummyOwners)
    assert(model and combat.records[model] and combat.dummyOwners[model]==configured and model:FindFirstChildOfClass('Humanoid').appliedUserId==11556197791,'Configured command bypassed original World Avatar or Combat behavior')
end)
check('dummy API preserves an exact original rig-loading failure',function()
    fixture();local owner=player(1357);local a=modules.AdminAccess.new();local world=dummyWorld(owner)
    world.templates.DummyRig:SetAttribute('FixtureCloneError','Original DummyRig clone permission denied')
    modules.KohlAdmin.start(nativeLoader(),a,world,2);advance(0)
    local ok,why=native:FindFirstChild('FunCombatDummy'):Invoke(owner)
    assert(ok==false and why:find('Original DummyRig clone permission denied',1,true),'Native dummy failure was hidden')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Admin regression scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'admin.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
