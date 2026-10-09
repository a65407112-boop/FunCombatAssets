return function(ctx)
    local scope=ctx.cleanup:scope()
    local listeners,queue={},{}
    local active=false
    local snapshotTime=-math.huge
    local protocol=assert(ctx.protocol,"Missing protocol configuration")
    local rs=game:GetService("ReplicatedStorage")
    local deadline=tick()+15
    local function find(parent,name,class)
        repeat
            local child=parent:FindFirstChild(name)
            if child then assert(child:IsA(class),"Wrong protocol class: "..name);return child end
            wait(0.05)
        until tick()>=deadline or ctx.cleanup.dead
        error("Matching FunCombat server is unavailable: "..name.." (15-second protocol timeout)")
    end
    local folder=find(rs,protocol.names.Folder,"Folder")
    local action=find(folder,protocol.names.Action,"RemoteEvent")
    local event=find(folder,protocol.names.Presentation,"RemoteEvent")
    local snapshot=find(folder,protocol.names.Snapshot,"RemoteFunction")
    local version=find(folder,protocol.names.Version,"IntValue")
    local build=find(folder,protocol.names.BuildId,"StringValue")
    assert(version.Value==protocol.version and (version.Value==4 or version.Value==5),"Protocol mismatch: use this build's funcombat_server.rbxl")
    assert(build.Value==ctx.manifest.buildId and build.Value==protocol.buildId,"Server and GitHub build IDs differ: install the matching server file")
    local events={};for name,id in pairs(protocol.eventIds) do events[id]=name end
    local module={}
    local reportedErrors=setmetatable({},{__mode="k"})
    local removedCharacters=setmetatable({},{__mode="k"})
    function module:reportError(data)
        if scope.dead or ctx.cancelled then return false end
        local character=data.character
        if character and (typeof(character)~="Instance" or not character.Parent or removedCharacters[character]) then return false end
        local player=game:GetService("Players").LocalPlayer
        if not player or not player.Parent then return false end
        if data.userId then
            if data.userId~=player.UserId
                or (character and character~=player.Character) then return false end
        end
        local key=character or self
        local text=tostring(data.text or "unspecified error")
        local seen=reportedErrors[key]
        if not seen then seen={};reportedErrors[key]=seen end
        if seen[text] then return false end
        seen[text]=true
        ctx.report("Server: "..text)
        return true
    end
    function module:on(kind,callback)
        listeners[kind]=listeners[kind] or {};local group=listeners[kind];group[callback]=true
        return function() group[callback]=nil end
    end
    function module:dispatch(kind,data)
        if kind=="Remove" and data.character then removedCharacters[data.character]=true end
        if kind=="Error" and not self:reportError(data) then return end
        for callback in pairs(listeners[kind] or {}) do
            local ok,why=pcall(callback,data)
            if not ok then ctx.report("Presentation "..tostring(kind)..": "..tostring(why)) end
        end
    end
    scope:add(event.OnClientEvent:Connect(function(id,data)
        if ctx.wire then data=ctx.wire:decode(data) end
        local kind=events[id]
        if kind and type(data)=="table" then
            -- A snapshot replaces state, but cannot replace a loading error.
            -- Report diagnostics immediately even while resource warm-up runs.
            if kind=="Error" then module:dispatch(kind,data)
            elseif active then if (data.serverTime or math.huge)>snapshotTime then module:dispatch(kind,data) end
            else
                if #queue>=2048 then table.remove(queue,1);ctx.report("Bootstrap event buffer overflow; refreshing from server state") end
                queue[#queue+1]={kind,data}
            end
        end
    end))
    function module:activate(cutoff)
        active=true
        snapshotTime=cutoff or snapshotTime
        local buffered=queue;queue={}
        for _,message in ipairs(buffered) do if (message[2].serverTime or math.huge)>snapshotTime then self:dispatch(message[1],message[2]) end end
    end
    function module:send(name,payload)
        local id=assert(protocol.actionIds[name],"Unknown action: "..tostring(name))
        if not ctx.cleanup.dead then action:FireServer(id,ctx.wire and ctx.wire:encode(payload) or payload) end
    end
    function module:snapshot()
        local sentAt=tick()
        local done,result,failure=false,nil,nil
        coroutine.wrap(function()
            local ok,data=pcall(function() return snapshot:InvokeServer() end)
            if ok then result=ctx.wire and ctx.wire:decode(data) or data else failure=data end;done=true
        end)()
        local untilTime=tick()+15
        repeat wait(0.05) until done or tick()>=untilTime or ctx.cleanup.dead
        assert(done and not failure,"Server snapshot failed or timed out: "..tostring(failure))
        assert(type(result)=="table" and result.version==protocol.version and result.buildId==protocol.buildId
            and type(result.states)=="table" and result.ready==true,"Invalid or not-ready server snapshot")
        self.serverOffset=(result.clockTime or result.serverTime or tick())-(sentAt+tick())/2
        return result
    end
    function module:now() return tick()+(self.serverOffset or 0) end
    function module:destroy() scope:destroy();listeners={};queue={} end
    return module
end
