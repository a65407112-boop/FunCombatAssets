-- Restore the native UI profiles from the attached place; no scene resources here.
return function(ctx,e,localPlayer)
    local data=assert(ctx.promptTemplates,'Missing original prompt definitions')
    assert(data.version==1 and data.parentPart=='Torso','Unsupported original prompt definitions')
    local enumTypes={KeyboardKeyCode=Enum.KeyCode,GamepadKeyCode=Enum.KeyCode,Exclusivity=Enum.ProximityPromptExclusivity,Style=Enum.ProximityPromptStyle}
    local installed={};local r=e.record
    local function profile(p,key)
        if installed[p]==key then return end
        local definition=assert(data.templates[key],'Missing original prompt template: '..key)
        for name,value in pairs(definition.properties)do
            if name~='Enabled'then
                if enumTypes[name]then value=assert(enumTypes[name][value],'Unsupported original prompt enum: '..name)
                elseif name=='UIOffset'then value=Vector2.new(value.x,value.y)end
                p[name]=value
            end
        end
        installed[p]=key
    end
    local function create(key)
        local p=Instance.new('ProximityPrompt');e.scope:add(p);profile(p,key)
        p.Enabled=false;p.Parent=e.parts.Torso;return p
    end
    e.gloryPrompt=create('executePrompt');e.prompt=create('carryPrompt');e.funPrompt=create('DefaultFun')
    e.scope:add(e.gloryPrompt.Triggered:Connect(function(sender)
        if sender==localPlayer and ctx.controller then ctx.controller:glory(r)end
    end))
    e.scope:add(e.prompt.Triggered:Connect(function(sender)
        if sender==localPlayer and ctx.controller then
            local actor=ctx.avatars:getLocal()
            if actor and r.carriedBy==actor then ctx.controller:drop()else ctx.controller:carry(r)end
        end
    end))
    e.scope:add(e.funPrompt.Triggered:Connect(function(sender)
        if sender==localPlayer and ctx.controller then
            local actor=ctx.avatars:getLocal();local link=actor and actor.dance
            local ok,why
            if link and link.a==actor and link.v==r then ok,why=ctx.controller:stopDance(r)
            else ok,why=ctx.controller:pairedDance(r)end
            if not ok then ctx.report(tostring(why))end
        end
    end))
    function e.updatePrompts(actor,distance)
        local ownsCarry=ctx.core:valid(actor)and r.carriedBy==actor or false
        local dance=ctx.core:valid(actor)and actor.dance
        local ownsDance=dance and dance.a==actor and dance.v==r or false
        profile(e.prompt,ownsCarry and 'dropPrompt'or 'carryPrompt')
        profile(e.gloryPrompt,ownsCarry and 'finishHoldPrompt'or 'executePrompt')
        profile(e.funPrompt,ownsDance and 'stopPrompt'or 'DefaultFun')
        e.prompt.Enabled=ownsCarry or ctx.core:canCarry(actor,r,distance)==true
        e.gloryPrompt.Enabled=ctx.core:canGlory(actor,r,distance)==true
        e.funPrompt.Enabled=ownsDance or ctx.core:canDance(actor,r,distance)==true
    end
end
