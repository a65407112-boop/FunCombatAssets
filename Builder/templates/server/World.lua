-- Original environment scripts, dummy chat commands and secret door.
local Players=game:GetService("Players")
local Storage=game:GetService("ServerStorage")
local Run=game:GetService("RunService")
local Data=require(script.Parent.WorldData)
local Policy=require(script.Parent.Policy)
local Avatar=require(script.Parent.Avatar)
local W={};W.__index=W
local function clock() return tick() end
local function thread(fn) coroutine.wrap(fn)() end
local function isCharacter(object)
    return object:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(object)
end
local function sourceSpawns(map)
    local folder=map and map:FindFirstChild("Spawns")
    local result={}
    if folder then for _,part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and (not part:IsA("SpawnLocation") or part.Enabled) then result[#result+1]=part end
    end end
    return result
end
local function describe(parent)
    if not parent then return "<missing>" end
    local names={}
    for _,child in ipairs(parent:GetChildren()) do names[#names+1]=child.Name.." ("..child.ClassName..")" end
    return #names>0 and table.concat(names,", ") or "<empty>"
end
function W.new(combat,templates)
    local self=setmetatable({combat=combat,templates=templates,tracked={},rotating={},connections={},teleports={},dummyCooldown={},doorAt=0,
        weather={name="Sunny",revision=1},weatherAt=clock()+720,activeMap=nil,nativePrompts={}},W)
    combat.world=self
    self:initializeMap()
    self:initializeSettings()
    return self
end
function W:initializeSettings()
    local configuration=workspace:FindFirstChild("Configuration")
    local flag=configuration and configuration:FindFirstChild("AllowDummys")
    if configuration then
        assert(configuration:IsA("Configuration") or configuration:IsA("Folder"),"Workspace.Configuration has an unexpected class; the original settings were not overwritten.")
    end
    if flag then
        assert(flag:IsA("BoolValue"),"Workspace.Configuration.AllowDummys must be the original BoolValue.")
        return flag -- An explicit false is an owner setting, not lost data.
    end
    local original=self.templates:FindFirstChild("WorldSettings")
    assert(original and original:IsA("Configuration"),"Original settings recovery template ServerStorage.FunCombatData.WorldSettings is missing.")
    local originalFlag=original:FindFirstChild("AllowDummys")
    assert(originalFlag and originalFlag:IsA("BoolValue"),"Original WorldSettings.AllowDummys BoolValue is missing.")
    if not configuration then
        configuration=assert(original:Clone(),"Original WorldSettings cannot be cloned.")
        configuration.Name="Configuration";configuration.Parent=workspace
        flag=configuration:FindFirstChild("AllowDummys")
    else
        flag=assert(originalFlag:Clone(),"Original AllowDummys cannot be cloned.");flag.Parent=configuration
    end
    warn("FunCombat restored original Workspace.Configuration.AllowDummys="..tostring(flag.Value).." from ServerStorage.FunCombatData.WorldSettings")
    return flag
end
function W:initializeMap()
    local name=Data.initialMap
    assert(type(name)=="string" and name~="","The source initial map name is missing from WorldData")
    local deadline=clock()+5
    repeat
        local stale={}
        for _,current in ipairs(workspace:GetChildren()) do
            if current.Name==name and current:IsA("Model") and not isCharacter(current) then
                if #sourceSpawns(current)>0 then
                    self.activeMap=current
                    return current
                end
                if self:isSourceMap(current) then stale[#stale+1]=current end
            end
        end
        local maps=self.templates:FindFirstChild("Maps")
        local template=maps and maps:FindFirstChild(name)
        if template and template:IsA("Model") and #sourceSpawns(template)>0 then
            local restored=template:Clone()
            assert(restored,"The original map template cannot be cloned: "..name)
            assert(#sourceSpawns(restored)>0,"The original map clone has no enabled spawns: "..name)
            for _,current in ipairs(stale) do current:Destroy() end
            restored.Parent=workspace
            self.activeMap=restored
            warn("FunCombat restored original map "..name.." from ServerStorage.FunCombatData.Maps")
            return restored
        end
        wait(0.05)
    until clock()>=deadline
    error("Could not initialize original map '"..name.."' within 5 seconds. Workspace: "..describe(workspace)
        .."; ServerStorage.FunCombatData.Maps: "..describe(self.templates:FindFirstChild("Maps")))
end
function W:isSourceMap(object)
    if not object:IsA("Model") or isCharacter(object) then return false end
    if object==self.activeMap then return true end
    local maps=self.templates:FindFirstChild("Maps")
    return maps~=nil and maps:FindFirstChild(object.Name)~=nil
        and (object:FindFirstChild("IsMap")~=nil or object:FindFirstChild("Spawns")~=nil)
end
function W:weatherState() return {name=self.weather.name,revision=self.weather.revision} end
function W:notice(text,category) self.combat:emit("Notice",{text=text,category=category}) end
function W:chooseWeather()
    local draw=math.random()*100
    local name
    if self.activeMap and self.activeMap.Name=="OriginalMap" then
        name=draw<=7 and "PurpleFog" or draw<=40 and "Cloudy" or draw<=60 and "Rainy" or "Sunny"
    else name=draw<=30 and "Rainy" or draw<=60 and "Cloudy" or "Sunny" end
    self.weather={name=name,revision=self.weather.revision+1}
    self.combat:emit("Weather",self:weatherState());self:notice("The Weather is changing to: "..name,"weather")
end
function W:spawns()
    return sourceSpawns(self.activeMap)
end
function W:spawn(r,index)
    local choices=self:spawns()
    if #choices==0 then return false,"Active source map has no enabled spawn locations" end
    local part=index and choices[(index-1)%#choices+1] or choices[math.random(1,#choices)]
    r.root.CFrame=part.CFrame*CFrame.new(math.random(-3,3),3,math.random(-3,3))
    -- Older Roblox-compatible velocity properties also clear an existing fall.
    r.root.Velocity=Vector3.new(0,0,0);r.root.RotVelocity=Vector3.new(0,0,0)
    return true
end
function W:secretDoor(player)
    local r=self.combat.players[player]
    if not Policy.free(self.combat:view(r)) or clock()<self.doorAt then return end
    local map=self.activeMap
    if not map or map.Name~="Crossroads" then return end
    local door=map:FindFirstChild("SecretDoor")
    if not door or not door:IsA("BasePart") then return end
    self.doorAt=clock()+1;door.CanCollide=not door.CanCollide
end
function W:dummy(player,userId)
    local function reject(why)
        self.combat:dummyFeedback(player,"rejected",why)
        return false,why
    end
    local allowed=workspace:FindFirstChild("Configuration")
    allowed=allowed and allowed:FindFirstChild("AllowDummys")
    local r=self.combat.players[player]
    if not allowed then return reject("Server Workspace.Configuration.AllowDummys is missing. Install the matching server place and restart the server.") end
    if not allowed:IsA("BoolValue") then return reject("Server Workspace.Configuration.AllowDummys is not a BoolValue.") end
    if not allowed.Value then return reject("Dummy spawning is disabled in this place.") end
    if not Policy.free(self.combat:view(r)) or r.character~=player.Character then return reject("Your character must be alive and free to spawn a dummy.") end
    if not Policy.request(self.combat:view(r),"SpawnDummy",userId,clock()) then return reject("Dummy avatar user ID must be a positive integer no greater than 100000000000.") end
    if clock()<(self.dummyCooldown[player] or 0) then return reject("Dummy cooldown: wait 3 seconds between requests.") end
    local all,owned=0,0
    for model,sender in pairs(self.combat.dummyOwners) do
        if model.Parent then all=all+1;if sender==player then owned=owned+1 end end
    end
    if all>=20 or owned>=4 then
        local why="Dummy limit: 4 per player, 20 per server"
        return reject(why)
    end
    local cloned,model=pcall(function() return self.templates.DummyRig:Clone() end)
    if not cloned or not model then return reject("Original dummy spawner failed: "..tostring(model or "DummyRig could not be cloned")) end
    local root=model:FindFirstChild("HumanoidRootPart")
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or not model:FindFirstChild("Torso") then
        model:Destroy();return reject("Original DummyRig is missing its R6 Humanoid, HumanoidRootPart or Torso.")
    end
    self.dummyCooldown[player]=clock()+3
    local ownerCharacter=r.character
    root.CFrame=r.root.CFrame*CFrame.new(0,0,-5)
    model.Name="Rig";model.Parent=workspace
    self.combat.dummyOwners[model]=player
    local name="Rig"
    local function dispose()
        if self.combat.records[model] then self.combat:remove(model) end
        self.combat.dummyOwners[model]=nil;model:Destroy()
    end
    thread(function()
        local ok,failure=pcall(function()
            if userId then
                root.Anchored=true
                local ready,why=Avatar.prepareDummy(player,model,humanoid,userId)
                if not ready then error(why or "Original avatar dummy preparation failed.") end
                if why and player.Parent then self.combat:emit("Error",{text=why,character=model},player) end
                if model.Parent then
                    name=tostring(userId)
                    thread(function()
                        local ok,username=pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
                        local record=self.combat.records[model]
                        if ok and record then record.displayName=username;self.combat:publish(record) end
                    end)
                end
            end
            if not model.Parent or not player.Parent or player.Character~=ownerCharacter then dispose();return end
            root.Anchored=false
            local record,why=self.combat:bind(model,nil,name)
            assert(record,"Original dummy rig could not initialize as R6: "..tostring(why))
            self.combat:dummyFeedback(player,"spawned","Combat dummy spawned.",model)
        end)
        if not ok then
            dispose()
            if player.Parent and player.Character==ownerCharacter then reject("Original dummy initialization failed: "..tostring(failure)) end
        end
    end)
    return true,"Dummy spawn accepted."
end
function W:playerRemoved(player)
    self.dummyCooldown[player]=nil
    for character in pairs(self.teleports) do if not character.Parent then self.teleports[character]=nil end end
end
function W:wallContact(r,wall)
    if not self.combat:alive(r) or r.downed or not r.ragdolled or r.busy or r.wallBounce
        or not wall:IsA("BasePart") or not wall.Parent or wall.Parent.Name~="BoundableWalls" then return end
    if not self.activeMap or not wall:IsDescendantOf(self.activeMap) then return end
    local localPoint=wall.CFrame:PointToObjectSpace(r.root.Position)
    local half=wall.Size*0.5
    if math.abs(localPoint.X)>half.X+5 or math.abs(localPoint.Y)>half.Y+5 or math.abs(localPoint.Z)>half.Z+5 then return end
    local sides={Vector3.new(half.X,localPoint.Y,localPoint.Z),Vector3.new(-half.X,localPoint.Y,localPoint.Z),
        Vector3.new(localPoint.X,localPoint.Y,half.Z),Vector3.new(localPoint.X,localPoint.Y,-half.Z)}
    local nearest=sides[1]
    for _,point in ipairs(sides) do if (point-localPoint).Magnitude<(nearest-localPoint).Magnitude then nearest=point end end
    local normal=Vector3.new(nearest.X-localPoint.X,0,nearest.Z-localPoint.Z)
    if normal.Magnitude<0.01 then return end
    normal=wall.CFrame:VectorToWorldSpace(normal.Unit)
    self.combat:setRagdoll(r,false)
    r.wallBounce=true;r.busy=true;r.wallUntil=clock()+1.5
    r.root.CFrame=CFrame.new(r.root.Position,r.root.Position+normal);r.root.Anchored=true
    self.combat:animation(r,"other/wallBounce",false,1.5)
    self.combat:effect(r,"effects/Hits/WallBounce",2)
    self.combat:sound(r,"audio/WallBounce");self.combat:sound(r,"audio/WallBounce2")
    self.combat:publish(r)
end
function W:track(object)
    if self.tracked[object] then return end
    local conns={};self.tracked[object]=conns
    local function connect(signal,fn) conns[#conns+1]=signal:Connect(fn) end
    if object:IsA("ProximityPrompt") and self.combat.protocol.config.mapPrompts[object.Name] then
        self.nativePrompts[object]=true
        local function allowed(player)
            local a=self.combat.players[player]
            local v=a and a.carrying
            local wall=object.Parent
            return a and v and object.Enabled and wall:IsA("BasePart") and self.activeMap and wall:IsDescendantOf(self.activeMap)
                and Policy.interact(self.combat:view(a),self.combat:view(v),4,(a.root.Position-wall.Position).Magnitude,object.MaxActivationDistance)
        end
        connect(object.PromptButtonHoldBegan,function(player)
            if allowed(player) then
                self.combat.holds[player]=self.combat.holds[player] or {}
                self.combat.holds[player][object]={actor=player.Character,target=self.combat.players[player].carrying.character,started=clock()}
            end
        end)
        connect(object.PromptButtonHoldEnded,function(player)
            local h=self.combat.holds[player] and self.combat.holds[player][object]
            if h then h.ended=clock() end
        end)
        connect(object.Triggered,function(player)
            local h=self.combat.holds[player] and self.combat.holds[player][object]
            if not h or not allowed(player) or h.actor~=player.Character
                or h.target~=self.combat.players[player].carrying.character or not Policy.holdReady(h,clock(),object.HoldDuration) then return end
            self.combat.holds[player][object]=nil
            local a=self.combat.players[player]
            if clock()<(a.nextInteraction or 0) then return end
            a.nextInteraction=clock()+0.35
            self.combat:beginPair(a,a.carrying,"Wall",object.Parent)
        end)
    elseif object:IsA("BasePart") and (object.Name=="KillPart" or object.Name=="killbox" or (object.Parent and (object.Parent.Name=="killbox" or object.Parent.Name=="KillPart"))) then
        connect(object.Touched,function(hit)
            local character=hit:FindFirstAncestorOfClass("Model")
            local record=character and self.combat.records[character]
            if self.combat:alive(record) and (record.root.Position-object.Position).Magnitude<=object.Size.Magnitude/2+8 then
                local mapKillbox=object.Name=="KillPart" or object.Name=="killbox" or (object.Parent and (object.Parent.Name=="killbox" or object.Parent.Name=="KillPart"))
                if mapKillbox then
                    record.iframes=false;record.downed=false;self.combat:sound(record,"audio/Killbox")
                end
                record.humanoid.Health=0
                if mapKillbox and record.player then
                    local player=record.player
                    thread(function()
                        wait(2)
                        if player.Parent and player.Character==character and not self.combat.noRespawn[player] then
                            local ok,why=pcall(function() player:LoadCharacter() end)
                            if not ok then warn("Original killbox respawn: "..tostring(why)) end
                        end
                    end)
                end
            end
        end)
    elseif object:IsA("BasePart") and object.Parent and object.Parent.Name=="TeleportParts"
        and (object.Name=="TeleportPart1" or object.Name=="TeleportPart2") then
        connect(object.Touched,function(hit)
            local character=hit:FindFirstAncestorOfClass("Model")
            local r=character and self.combat.records[character]
            if not Policy.free(self.combat:view(r)) or clock()<(self.teleports[character] or 0) then return end
            if (r.root.Position-object.Position).Magnitude>object.Size.Magnitude/2+8 then return end
            local target=object.Parent:FindFirstChild(object.Name=="TeleportPart1" and "TeleportPart2" or "TeleportPart1")
            if target and target:IsA("BasePart") then self.teleports[character]=clock()+1;r.root.CFrame=target.CFrame+Vector3.new(0,5,0) end
        end)
    elseif object.Name=="Cirno" and object:IsA("BasePart") then self.rotating[object]=true
    elseif object:IsA("ClickDetector") then
        local button=object.Parent
        local tv=button and button.Parent
        local screen=tv and tv:FindFirstChild("Screen")
        if screen and tv.Name=="TV" and screen:IsA("BasePart") then
            connect(object.MouseClick,function(player)
                local r=self.combat.players[player]
                if not Policy.free(self.combat:view(r)) or (r.root.Position-button.Position).Magnitude>object.MaxActivationDistance then return end
                if clock()<(self.tvAt or 0) then return end
                self.tvAt=clock()+0.15
                local music=screen:FindFirstChildOfClass("Sound")
                local channel=screen:FindFirstChild("Channel")
                local volume=music and music:FindFirstChild("VolumeValue")
                local image=screen:FindFirstChildOfClass("Decal")
                local light=screen:FindFirstChildOfClass("SurfaceLight")
                if not music or not channel or not volume then return end
                if button.Name=="CButtonDown" then channel.Value=(channel.Value-2)%#Data.tvSongs+1
                elseif button.Name=="CButtonUp" then channel.Value=channel.Value%#Data.tvSongs+1
                elseif button.Name=="VButtonDown" then volume.Value=math.max(0,volume.Value-0.1)
                elseif button.Name=="VButtonUp" then volume.Value=math.min(1.2,volume.Value+0.1)
                elseif button.Name=="ButtonOn/Off" then
                    local enabled=not (light and light.Enabled)
                    if light then light.Enabled=enabled end
                    if image then image.Transparency=enabled and 0 or 1 end
                    screen.BrickColor=enabled and BrickColor.White() or BrickColor.Black()
                    screen.Material=enabled and Enum.Material.Neon or Enum.Material.Glass
                    if enabled then music:Play() else music:Pause() end
                end
                if button.Name=="CButtonDown" or button.Name=="CButtonUp" then
                    music.SoundId=Data.tvSongs[channel.Value]
                    if image then image.Texture=Data.tvImages[channel.Value] end
                    if light and light.Enabled then music:Play() end
                end
                music.Volume=volume.Value
            end)
        end
    end
    if #conns>0 or self.rotating[object] then
        connect(object.AncestryChanged,function(_,parent)
            if not parent then
                for _,conn in ipairs(conns) do conn:Disconnect() end
                self.tracked[object]=nil;self.rotating[object]=nil;self.nativePrompts[object]=nil
            end
        end)
    else self.tracked[object]=nil end
end
function W:start()
    self.connections[#self.connections+1]=workspace.DescendantAdded:Connect(function(object) self:track(object) end)
    for _,object in ipairs(workspace:GetDescendants()) do self:track(object) end
    self.connections[#self.connections+1]=Run.Heartbeat:Connect(function(dt)
        local carrying=false
        for _,record in pairs(self.combat.players) do
            if record.carrying and self.combat:alive(record) and not record.busy and not record.downed then carrying=true;break end
        end
        for prompt in pairs(self.nativePrompts) do
            local enabled=carrying and prompt:IsDescendantOf(self.activeMap or workspace) or false
            if prompt.Enabled~=enabled then prompt.Enabled=enabled end
        end
        for part in pairs(self.rotating) do if part.Parent then part.CFrame=part.CFrame*CFrame.Angles(0,0,0.05) end end
        if #Players:GetPlayers()>1 and clock()>=self.weatherAt then self.weatherAt=clock()+720;self:chooseWeather() end
    end)
    local music=self.templates:FindFirstChild("MapMusic")
    if music then
        music=music:Clone();music.Parent=workspace
        local function play()
            if music.Parent then music.SoundId="rbxassetid://"..Data.music[math.random(1,#Data.music)];music:Play() end
        end
        play();self.connections[#self.connections+1]=music.Ended:Connect(function() thread(function() wait(3);play() end) end)
    end
end
return W
