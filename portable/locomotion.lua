-- Original Animate IDs and lean constants, applied only to our local R6 proxy.
local L={}
function L.mode(state,speed,locked)
    if locked then return nil end
    if state=='Jumping'then return 'jump'
    elseif state=='Freefall'or state=='FallingDown'then return 'fall'
    elseif state=='Climbing'then return 'climb'
    elseif state=='Seated'then return 'sit'
    elseif speed>0.01 then return 'walk'end
    return 'idle'
end
function L.new(ctx)
    local scope=ctx.cleanup:scope();local records={}
    local definitions=ctx.json('assets/animations/locomotion.json')
    local function stop(r)
        if r.track then pcall(function()r.track:Stop(0.1);r.track:Destroy()end);r.track=nil end
        r.mode=nil
    end
    local function remove(character)local r=records[character];records[character]=nil;if r then r.scope:destroy()end end
    local function attach(state)
        if not state or not state.character or records[state.character]then return end
        local virtual=ctx.avatars.byModel[state.character];local avatar=virtual and virtual.avatar
        if not avatar then return end
        local hum=avatar.model:FindFirstChildOfClass('Humanoid');if not hum then return end
        local owner=scope:scope()
        local animator=hum:FindFirstChildOfClass('Animator')
        if not animator then animator=Instance.new('Animator');animator.Parent=hum;owner:add(animator)end
        local r={scope=owner,avatar=avatar,animator=animator,humanoid=hum,animations={},failed={}}
        records[state.character]=r
        for path,data in pairs(definitions)do
            local mode=path:match('^([^/]+)/')
            if mode and data.AnimationId~='rbxassetid://0'and mode~='toolnone'then
                local a=Instance.new('Animation');a.Name=data.Name;a.AnimationId=data.AnimationId;owner:add(a)
                r.animations[mode]=r.animations[mode]or{};table.insert(r.animations[mode],{animation=a,weight=data.weight or 1})
            end
        end
        r.rootJoint=avatar.joints.RootJoint;r.originalRoot=r.rootJoint and r.rootJoint.C0
        owner:add(function()stop(r)end)
    end
    scope:add(ctx.state:onChanged(attach))
    scope:add(ctx.network:on('Remove',function(data)if data then remove(data.character)end end))
    for _,state in pairs(ctx.state:all())do attach(state)end
    scope:add(game:GetService('RunService').Heartbeat:Connect(function(dt)
        for character,r in pairs(records)do
            local e=r.avatar;local virtual=ctx.avatars.byModel[character]
            if not character.Parent or not virtual or not e.root.Parent then remove(character)
            else
                local velocity=e.root.Velocity;local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
                local ok,state=pcall(function()return e.humanoid:GetState().Name end);if not ok then state=''end
                local locked=virtual.downed or virtual.ragdolled or virtual.carriedBy or virtual.busy or ctx.animations:blocksLocomotion(character)
                local mode=L.mode(state,speed,locked)
                if mode~=r.mode then
                    stop(r)
                    local choices=mode and r.animations[mode]
                    if choices and not r.failed[mode]then
                        local total=0;for _,c in ipairs(choices)do total=total+c.weight end
                        local pick=math.random()*total;local selected=choices[1]
                        for _,c in ipairs(choices)do pick=pick-c.weight;if pick<=0 then selected=c;break end end
                        local loaded,track=pcall(function()return r.animator:LoadAnimation(selected.animation)end)
                        if not loaded then r.failed[mode]=true;ctx.report('Original R6 '..mode..' unavailable: '..selected.animation.AnimationId..': '..tostring(track))
                        else
                            r.track=track;r.mode=mode;r.deadline=tick()+15;r.checked=false
                            track.Priority=Enum.AnimationPriority.Core;track.Looped=mode~='jump';track:Play(mode=='fall'and 0.3 or 0.1)
                        end
                    end
                end
                if r.track then
                    if mode=='walk'then r.track:AdjustSpeed(speed/14.5)
                    elseif mode=='climb'then r.track:AdjustSpeed(math.abs(velocity.Y)/12)end
                    if not r.checked then
                        if r.track.Length>0 then r.checked=true
                        elseif tick()>=r.deadline then r.failed[mode]=true;ctx.report('Original R6 animation did not load within 15s: '..tostring(mode));stop(r)end
                    end
                end
                if r.rootJoint and r.rootJoint.Parent then
                    if locked then r.rootJoint.C0=r.originalRoot
                    else
                        local horizontal=Vector3.new(velocity.X,0,velocity.Z)
                        local movement=horizontal.Magnitude>0.01 and horizontal.Unit or Vector3.new()
                        local direction=e.root.CFrame:VectorToObjectSpace(movement)
                        r.rootJoint.C0=r.rootJoint.C0:Lerp(r.originalRoot*CFrame.Angles(-direction.Z*0.13/2,-direction.X*0.13,0),math.min(1,dt*7))
                    end
                end
            end
        end
    end))
    return {destroy=function()scope:destroy()end}
end
return L
