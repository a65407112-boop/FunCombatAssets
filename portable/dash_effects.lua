-- Original dash limb trails/smoke and white flash, on owned visual copies only.
return function(ctx)
    local scope=ctx.cleanup:scope();local active={};local module={}
    local function finite(v,default)
        return type(v)=='number'and v==v and math.abs(v)~=math.huge and v or default
    end
    local function stop(entry)
        if entry.disabled then return end;entry.disabled=true
        for _,v in ipairs(entry.emitters)do if v.Parent then v.Enabled=false end end
    end
    local function install(entry,key,part)
        local source=ctx.assets:clone(key);entry.scope:add(source)
        -- Keep the whole clone until its children have been moved together;
        -- this preserves the original Trail.Attachment0/1 references.
        for _,v in ipairs(source:GetDescendants())do
            assert(not v:IsA('BasePart'),'Original dash effect has an unsupported physical descendant: '..key)
            if v:IsA('ParticleEmitter')or v:IsA('Trail')then
                v.Enabled=true;entry.emitters[#entry.emitters+1]=v
                local life=v:IsA('ParticleEmitter')and v.Lifetime.Max or v.Lifetime
                entry.ends=math.max(entry.ends,entry.disableAt+math.min(30,math.max(0,finite(life,1)))+0.1)
            end
        end
        for _,child in ipairs(source:GetChildren())do entry.scope:add(child);child.Parent=part end
    end
    function module:play(data)
        if type(data)~='table'or (data.key~='effects/dash_limbs'and data.key~='effects/dash_smoke')then return end
        local character=data.character
        if not ctx.avatars.byModel[character]or not character.Parent then return end
        local seconds=math.max(0.01,math.min(1,finite(data.duration,0.3)));local now=tick()
        local entry={scope=scope:scope(),character=character,emitters={},disableAt=now+seconds,ends=now+seconds+2,started=now}
        active[entry]=true;entry.scope:add(function()active[entry]=nil end)
        local ok,why=pcall(function()
            if data.key=='effects/dash_limbs'then
                for _,name in ipairs({'Left Arm','Right Arm','Left Leg','Right Leg'})do
                    local limb=character:FindFirstChild(name);if limb then install(entry,data.key,limb)end
                end
                local made,highlight=pcall(Instance.new,'Highlight')
                if made then
                    entry.scope:add(highlight);entry.highlight=highlight
                    highlight.Name='Highlight';highlight.DepthMode=Enum.HighlightDepthMode.Occluded
                    highlight.FillColor=Color3.new(1,1,1);highlight.OutlineColor=Color3.new(1,1,1)
                    highlight.FillTransparency=0.5;highlight.OutlineTransparency=0
                    highlight.Adornee=character;highlight.Parent=character
                else ctx.report('Original dash flash unavailable: '..tostring(highlight))end
            else
                local root=character:FindFirstChild('HumanoidRootPart');if root then install(entry,data.key,root)end
            end
        end)
        if not ok then entry.scope:destroy();ctx.report('Original dash effect failed: '..tostring(why))end
    end
    scope:add(ctx.network:on('Effect',function(data)module:play(data)end))
    scope:add(ctx.network:on('Remove',function(data)
        local remove={};for e in pairs(active)do if data and e.character==data.character then remove[#remove+1]=e end end
        for _,e in ipairs(remove)do e.scope:destroy()end
    end))
    scope:add(ctx.network:on('DashStop',function(data)
        for e in pairs(active)do if data and e.character==data.character then stop(e)end end
    end))
    scope:add(game:GetService('RunService').Heartbeat:Connect(function()
        local now=tick();local remove={}
        for e in pairs(active)do
            if not e.character.Parent or now>=e.ends then remove[#remove+1]=e
            else
                if now>=e.disableAt then stop(e)end
                if e.highlight then
                    local alpha=math.max(0,math.min(1,(now-e.started)/0.4))
                    e.highlight.FillTransparency=0.5+0.5*alpha;e.highlight.OutlineTransparency=alpha
                    if alpha>=1 then e.scope:remove(e.highlight);e.highlight:Destroy();e.highlight=nil end
                end
            end
        end
        for _,e in ipairs(remove)do e.scope:destroy()end
    end))
    function module:destroy()scope:destroy()end
    return module
end
