-- Prepare the actual replicated avatar resources as they appear. This module
-- never changes a head, a material, a texture reference, or the combat rig.
-- A completed request is not evidence that Roblox has rendered a dynamic head.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local players=game:GetService("Players")
    local provider=game:GetService("ContentProvider")
    local characters,owners={},{}
    local retired=setmetatable({},{__mode="k"})
    local timeout=math.max(0.1,tonumber(ctx.config.Timeout) or 20)
    local properties={
        MeshPart={"MeshId","MeshContent","TextureID","TextureContent"},
        SpecialMesh={"MeshId","TextureId"},Decal={"Texture","ColorMapContent"},
        Texture={"Texture","ColorMapContent"},Animation={"AnimationId"},Sound={"SoundId"},
        ImageLabel={"Image"},ImageButton={"Image"},ParticleEmitter={"Texture"},
        Beam={"Texture"},Trail={"Texture"}
    }
    local function valid(record)
        return not scope.dead and not ctx.cancelled and not record.scope.dead and record.character.Parent
            and (not record.owner or (record.owner.Parent and record.owner.Character==record.character))
    end
    local function belongs(record,object)
        local root=object
        while root and root.Parent~=record.character do root=root.Parent end
        return root and (root.Name=="Head" or root:IsA("Accessory"))
    end
    local function references(object,keys)
        local values={}
        for _,key in ipairs(keys) do
            local ok,value=pcall(function() return object[key] end)
            if ok and value~=nil and tostring(value)~="" then values[#values+1]=key.."="..tostring(value) end
        end
        return table.concat(values,", ")
    end
    local schedule
    local function warm(record)
        local content,refs={},{}
        for value,label in pairs(record.pending) do
            if (type(value)=="string" and value==record.mood)
                or (typeof(value)=="Instance" and belongs(record,value)) then
                content[#content+1]=value;refs[#refs+1]=label
            end
        end
        record.pending={}
        if #content==0 or not valid(record) then return end
        record.busy=true
        record.nativeBusy=true
        local done=false
        coroutine.wrap(function()
            local ok,why=pcall(function()
                provider:PreloadAsync(content,function(asset,status)
                    local value=tostring(status)
                    if valid(record) and (value:find("Failure") or value:find("TimedOut")) then
                        local key=tostring(asset).."/"..value
                        if not record.failures[key] then
                            record.failures[key]=true
                            ctx.report("Original avatar content unavailable for "..record.character.Name..": "
                                ..tostring(asset).." ("..value..")")
                        end
                    end
                end)
            end)
            if not ok and valid(record) then
                ctx.report("Original avatar content preload for "..record.character.Name..": "..tostring(why)
                    .."; requested "..table.concat(refs,"; "))
            end
            done=true
            record.nativeBusy=false
            if valid(record) and next(record.pending) then schedule(record) end
        end)()
        local deadline=tick()+timeout
        while not done and valid(record) and tick()<deadline do wait(0.05) end
        if not done and valid(record) then
            ctx.report("Original avatar content timed out after "..timeout.." seconds for "..record.character.Name
                ..": "..table.concat(refs,"; ")..". Roblox may continue loading; availability has not been confirmed.")
        end
        record.busy=false
        if valid(record) and next(record.pending) then schedule(record) end
    end
    schedule=function(record)
        -- Luau cannot cancel an engine preload already in flight. Its monitor
        -- stops at the deadline; further edits wait for that single native call
        -- instead of starting an unbounded set of stalled requests.
        if record.scheduled or record.busy or record.nativeBusy or scope.dead or record.scope.dead then return end
        record.scheduled=true
        coroutine.wrap(function()
            wait(0.05)
            record.scheduled=false
            if valid(record) then warm(record) end
        end)()
    end
    local function enqueue(record,object)
        local keys=properties[object.ClassName]
        if not keys or not belongs(record,object) then return end
        local signature=references(object,keys)
        if record.seen[object]==signature then return end
        record.seen[object]=signature
        record.pending[object]=object.ClassName.." "..object.Name.." ["..signature.."]"
        schedule(record)
    end
    local function watch(record,object)
        if not belongs(record,object) then return end
        if object:IsA("SurfaceAppearance") then
            if not record.surfaces[object] and valid(record) then
                record.surfaces[object]=true
                ctx.report("Original avatar SurfaceAppearance on "..record.character.Name.."."..object.Parent.Name
                    .." uses processed texture packs streamed by Roblox; PreloadAsync does not confirm their availability.")
            end
            return
        end
        if not properties[object.ClassName] then return end
        if not record.watched[object] then
            record.watched[object]=true
            for _,key in ipairs(properties[object.ClassName]) do
                pcall(function()
                    record.scope:add(object:GetPropertyChangedSignal(key):Connect(function() enqueue(record,object) end))
                end)
            end
        end
        enqueue(record,object)
    end
    local function diagnostic(record)
        if not valid(record) then return end
        local value=record.character:GetAttribute("1e5b028e37f8")
        if type(value)=="string" and value~="" and not record.diagnostics[value] then
            record.diagnostics[value]=true
            local data={text=value,character=record.character,userId=record.owner and record.owner.UserId}
            if ctx.network.reportError then ctx.network:reportError(data)
            else ctx.report("Server: "..value) end
        end
    end
    local function mood(record)
        local id=tonumber(record.character:GetAttribute("0e807e2b2887")) or 0
        local value=id>0 and id%1==0 and "rbxassetid://"..id or nil
        if record.mood==value then return end
        if record.mood then record.pending[record.mood]=nil end
        record.mood=value
        if value then record.pending[value]=value;schedule(record) end
    end
    local function scan(record)
        for _,object in ipairs(record.character:GetDescendants()) do watch(record,object) end
        mood(record);diagnostic(record)
        if next(record.pending) then schedule(record) end
    end
    local function remove(character)
        retired[character]=true
        local record=characters[character]
        if record then characters[character]=nil;record.scope:destroy() end
    end
    local function attach(character,owner)
        if scope.dead or ctx.cancelled or not character or retired[character] then return end
        if characters[character] then return end
        local record={character=character,owner=owner,scope=scope:scope(),pending={},seen={},watched={},surfaces={},
            failures={},diagnostics={},wasParented=character.Parent~=nil}
        characters[character]=record
        record.scope:add(character.DescendantAdded:Connect(function(object) watch(record,object) end))
        record.scope:add(character:GetAttributeChangedSignal("544273c2cf5a"):Connect(function() mood(record) end))
        record.scope:add(character:GetAttributeChangedSignal("0e807e2b2887"):Connect(function() mood(record) end))
        record.scope:add(character:GetAttributeChangedSignal("1e5b028e37f8"):Connect(function() diagnostic(record) end))
        record.scope:add(character.AncestryChanged:Connect(function()
            if character.Parent then record.wasParented=true;scan(record)
            elseif record.wasParented then remove(character) end
        end))
        scan(record)
    end
    local function addPlayer(player)
        if owners[player] or scope.dead or ctx.cancelled then return end
        local owner={scope=scope:scope()};owners[player]=owner
        local function added(character)
            if owner.character and owner.character~=character then remove(owner.character) end
            owner.character=character;attach(character,player)
        end
        owner.scope:add(player.CharacterAdded:Connect(added))
        owner.scope:add(player.CharacterRemoving:Connect(remove))
        if player.Character then added(player.Character) end
    end
    scope:add(players.PlayerAdded:Connect(addPlayer))
    scope:add(players.PlayerRemoving:Connect(function(player)
        local owner=owners[player]
        if owner then
            if owner.character then remove(owner.character) end
            owners[player]=nil;owner.scope:destroy()
        end
    end))
    for _,player in ipairs(players:GetPlayers()) do addPlayer(player) end
    scope:add(ctx.state:onChanged(function(state)
        local character=state.character
        if character then attach(character,players:GetPlayerFromCharacter(character)) end
    end))
    for character in pairs(ctx.state:all()) do attach(character,players:GetPlayerFromCharacter(character)) end
    scope:add(ctx.network:on("Remove",function(data) if data.character then remove(data.character) end end))
    local module={}
    function module:destroy() scope:destroy();characters={};owners={} end
    return module
end
