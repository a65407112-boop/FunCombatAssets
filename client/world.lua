-- Native visible geometry is downloaded; the server retains matching physics.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local config=assert(ctx.protocol.clientWorld,"Client world configuration is missing")
    local Players=game:GetService("Players")
    local Run=game:GetService("RunService")
    local RS=game:GetService("ReplicatedStorage")
    local module={active=false}
    local session
    ctx.participants:setActive(false)
    local function find(parent,alias,nodeId)
        if nodeId then
            for _,object in ipairs(parent:GetChildren()) do
                if object:GetAttribute(config.nodeAttribute)==nodeId then return object end
            end
            return
        end
        local label=ctx.identifiers.objectNames[alias]
        return parent:FindFirstChild(alias) or label and parent:FindFirstChild(label)
    end
    local function await(parent,alias,nodeId)
        local deadline=tick()+ctx.config.Timeout
        repeat
            local object=find(parent,alias,nodeId)
            if object then return object end
            wait(.05)
        until tick()>=deadline or scope.dead
        error("Client world dependency did not replicate: "..alias)
    end
    local net=await(RS,ctx.protocol.names.Folder)
    local remote=await(net,config.remote)
    local function request(op,info,identity)
        assert(not scope.dead and not ctx.cancelled,"Client world request cancelled")
        local data={op=op,buildId=ctx.manifest.buildId,session=identity or session}
        if info then data.mapKey=info.mapKey;data.revision=info.revision end
        local done,response,failure=false,nil,nil
        coroutine.wrap(function()
            local ok,result=pcall(function() return remote:InvokeServer(data) end)
            if ok then response=result else failure=result end
            done=true
        end)()
        local deadline=tick()+15
        repeat if done then break end;wait(.05) until tick()>=deadline or scope.dead
        assert(not scope.dead and not ctx.cancelled,"Client world response cancelled")
        assert(done and not failure and type(response)=="table","Client world request failed: "..tostring(failure or "timeout"))
        assert(response.buildId==ctx.manifest.buildId,"Client world build mismatch")
        return response
    end
    local function leave()
        local identity=session;session=nil
        ctx.participants:setActive(false)
        if identity then return request("leave",nil,identity) end
    end
    local function open()
        if session then return end
        local result=request("open")
        assert(result.accepted and type(result.session)=="number","World loader session was not opened")
        session=result.session
    end
    local dynamic={}
    local function prepare(root)
        local all=root:GetDescendants();all[#all+1]=root
        for _,object in ipairs(all) do
            if object:IsA("BasePart") then
                object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false
                if object:IsA("SpawnLocation") then object.Enabled=false end
            elseif object:IsA("ProximityPrompt") then object.Enabled=false
            elseif object:IsA("ClickDetector") then object.MaxActivationDistance=0
            elseif object:IsA("Sound") then object.Playing=false;object.Volume=0
            elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
                -- These continue to illuminate the same geometry on the server.
                object.Enabled=false
            end
        end
    end
    local function bindVisual(root,serverRoot,owned)
        local visuals={}
        local visibleObjects=root:GetDescendants();visibleObjects[#visibleObjects+1]=root
        for _,object in ipairs(visibleObjects) do
            local id=object:GetAttribute(config.nodeAttribute)
            if id then visuals[id]=object end
        end
        local function bind(server)
            local visual=visuals[server:GetAttribute(config.nodeAttribute)]
            if not visual then return end
            if server:IsA("BasePart") then
                visual.CFrame=server.CFrame
                local name=ctx.identifiers.objectNames[server.Name] or server.Name
                if not server.Anchored or name=="Cirno" then dynamic[#dynamic+1]={server,visual,owned} end
            end
            owned:add(server.Changed:Connect(function(key)
                if owned.dead or not visual.Parent then return end
                if server:IsA("BasePart") and (key=="CFrame" or key=="Size" or key=="Color" or key=="Material")
                    or (server:IsA("Decal") or server:IsA("Texture")) and (key=="Texture" or key=="Transparency" or key=="Color3")
                    or (server:IsA("TextLabel") or server:IsA("TextButton")) and key=="Text" then
                    pcall(function() visual[key]=server[key] end)
                end
            end))
        end
        owned:add(serverRoot.DescendantAdded:Connect(bind))
        bind(serverRoot)
        for _,server in ipairs(serverRoot:GetDescendants()) do bind(server) end
    end
    local scene,sceneScope,revision,mapKey
    local function clearScene()
        if sceneScope then sceneScope:destroy();sceneScope=nil end
        if scene then scene:Destroy();scene=nil end
        revision=nil;mapKey=nil
    end
    local function mount(info)
        clearScene()
        local root=ctx.assets:clone(info.mapKey)
        local ok,why=pcall(function()
            assert(not scope.dead,"Client world loading cancelled")
            prepare(root);root.Name="FunCombat_ClientWorld"
            local serverRoot=await(workspace,info.mapAlias)
            sceneScope=scope:scope()
            root.Parent=workspace;bindVisual(root,serverRoot,sceneScope)
        end)
        if not ok then root:Destroy();if sceneScope then sceneScope:destroy();sceneScope=nil end;error(why) end
        scene=root;revision=info.revision;mapKey=info.mapKey
    end
    if config.staticAsset then
        local environment=ctx.assets:clone(config.staticAsset)
        local ok,why=pcall(function()
            prepare(environment);environment.Name="FunCombat_ClientEnvironment";environment.Parent=workspace
            scope:add(environment)
            for _,entry in ipairs(config.staticRoots or {}) do
                local original=await(workspace,entry.alias,entry.nodeId)
                bindVisual(environment,original,scope)
            end
        end)
        if not ok then environment:Destroy();error(why) end
    end
    local function synchronize(join)
        for _=1,3 do
            assert(not scope.dead,"Client world synchronization cancelled")
            open()
            local info=request("status")
            assert(info.accepted,info.error or "World loader session rejected")
            assert(info.available and type(info.mapKey)=="string","Server has no available world")
            if info.revision~=revision or info.mapKey~=mapKey then
                if info.joined then leave();open();info=request("status") end
                mount(info)
            end
            if not join then return end
            assert(not scope.dead and not ctx.cancelled,"Client world entry cancelled")
            local result=request("join",info)
            if result.accepted then ctx.participants:setActive(true);return end
            if result.revision==info.revision then error(result.error or "World entry rejected") end
        end
        error("Map kept changing during client world loading")
    end
    scope:add(clearScene)
    scope:add(function()
        module.active=false
        ctx.participants:setActive(false)
        local identity=session;session=nil
        if identity then
            coroutine.wrap(function() pcall(function()
                remote:InvokeServer({op="leave",buildId=ctx.manifest.buildId,session=identity})
            end) end)()
        end
    end)
    synchronize(false)
    function module:activate() synchronize(true);self.active=true end
    local busy=false
    local elapsed,motion=0,0
    scope:add(Run.Heartbeat:Connect(function(dt)
        motion+=dt
        if motion>=.05 then
            motion=0
            for i=#dynamic,1,-1 do
                local pair=dynamic[i]
                if pair[3].dead or not pair[1].Parent or not pair[2].Parent then table.remove(dynamic,i)
                else pair[2].CFrame=pair[1].CFrame end
            end
        end
        elapsed+=dt
        if elapsed<1 or busy or not module.active then return end
        elapsed=0;busy=true
        coroutine.wrap(function()
            local ok,why=pcall(synchronize,true)
            busy=false
            if not ok and not scope.dead then
                clearScene()
                pcall(leave)
                ctx.report("Client world: "..tostring(why))
            end
        end)()
    end))
    function module:destroy() scope:destroy() end
    return module
end
