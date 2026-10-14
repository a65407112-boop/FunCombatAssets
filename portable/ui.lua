-- Restore original GUI packages. Only their action/state adapter is portable.
return function(ctx)
    local scope=ctx.cleanup:scope()
    local Players=game:GetService("Players")
    local Input=game:GetService("UserInputService")
    local Run=game:GetService("RunService")
    local Tween=game:GetService("TweenService")
    local player=Players.LocalPlayer
    local roots,billboards,tweens={},{},{}
    local module={roots=roots}
    local genderColors={
        Female={Color3.fromRGB(170,86,162),Color3.fromRGB(35,23,34)},
        Male={Color3.fromRGB(27,175,158),Color3.fromRGB(26,42,53)},
        Fembxy={Color3.fromRGB(72,0,130),Color3.fromRGB(26,42,53)}
    }
    local function find(root,name)return root and root:FindFirstChild(name,true)end
    local function text(object,value)if object and (object:IsA("TextLabel")or object:IsA("TextButton"))then object.Text=tostring(value)end end
    local function clone(name)
        local key="gui/"..name
        if not ctx.catalog.packages[key]then return nil end
        local gui=ctx.assets:clone(key)
        if scope.dead then gui:Destroy();return nil end
        scope:add(gui);gui.ResetOnSpawn=false;return gui
    end
    local function cancel(object)
        local old=tweens[object]
        if old then tweens[object]=nil;old.connection:Disconnect();old.tween:Cancel()end
    end
    local function tween(object,seconds,properties)
        if not object then return end;cancel(object)
        local t=Tween:Create(object,TweenInfo.new(seconds,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),properties)
        local entry={tween=t};tweens[object]=entry
        entry.connection=t.Completed:Connect(function()entry.connection:Disconnect();if tweens[object]==entry then tweens[object]=nil end end)
        t:Play()
    end
    local function bind(button,fn)
        if not button or not button:IsA("GuiButton")then return end
        scope:add(button.Activated:Connect(function()
            if scope.dead then return end
            local press=find(button,"Press");if press then ctx.audio:play({sound=press})end
            local ok,why=fn();if ok==false and why then module:status(why)end
        end))
    end
    for _,name in ipairs({"weapon","weaponGui","Gender","title","Subtitles","Emotes","HitboxToggle","mobileButtons","getUp","HitIndicator"})do
        local gui=clone(name);roots[name]=gui
        if gui then gui.Parent=ctx.guiParent();gui.Enabled=name~="weapon"end
    end
    for _,name in ipairs({"stats","Info","society","completionLeader","BillboardGui"})do roots[name]=clone(name)end
    if roots.mobileButtons then roots.mobileButtons.Enabled=Input.TouchEnabled end
    local dash=find(roots.mobileButtons,"Dash");if dash then dash.Visible=false end
    bind(dash,function()return ctx.controller:dash()end)
    local unused=find(roots.mobileButtons,"R");if unused then unused.Visible=false end
    if ctx.modules and ctx.modules.dance_meter then
        module.danceMeter=ctx.modules.dance_meter(ctx,roots.mobileButtons);scope:add(module.danceMeter)
    end
    local getUp=find(roots.mobileButtons,"GetUp");if getUp then getUp.Visible=false end
    local getUpFrame=find(roots.getUp,"Frame");if getUpFrame then getUpFrame.Visible=false end
    local subtitle=find(roots.Subtitles,"TextLabel")
    local statusUntil=0
    function module:status(value)
        statusUntil=tick()+6
        if subtitle then subtitle.Text=tostring(value);subtitle.TextTransparency=0;subtitle.TextStrokeTransparency=0.5 end
    end
    for name in pairs(genderColors)do
        local value=name;local button=find(roots.Gender,name)
        bind(button,function()ctx.audio:play({key="audio/Gender/Click"});return ctx.controller:selectGender(value)end)
        if button then
            scope:add(button.MouseEnter:Connect(function()ctx.audio:play({key="audio/Gender/Hover"});tween(button,0.1,{Rotation=-3})end))
            scope:add(button.MouseLeave:Connect(function()tween(button,0.1,{Rotation=0})end))
        end
    end
    local selectedWeapon
    local weaponButtons={Bat="Bat",Sword="Sword",Sword2=":3",Sword3="BoyKisser",cat="Maxwell",cat2="Orange Cat"}
    for buttonName,name in pairs(weaponButtons)do
        local value=name
        bind(find(roots.weapon,buttonName),function()
            selectedWeapon=value
            local ok,why=ctx.controller:equip(value)
            if not ok then selectedWeapon=nil end
            return ok,why
        end)
    end
    bind(roots.weaponGui and roots.weaponGui:FindFirstChildWhichIsA("GuiButton",true),function()
        if roots.weapon then roots.weapon.Enabled=not roots.weapon.Enabled end;return true
    end)
    local hitboxes=false
    local hitboxButton=roots.HitboxToggle and roots.HitboxToggle:FindFirstChildWhichIsA("GuiButton",true)
    bind(hitboxButton,function()
        hitboxes=not hitboxes
        local toggle=find(roots.HitboxToggle,"Toggle");if toggle then toggle.Value=hitboxes end
        text(find(hitboxButton,"TextLabel"),hitboxes and "Hitboxes: On"or"Hitboxes: Off")
        ctx.avatars:showHitboxes(hitboxes);return true
    end)
    local emoteDisplay=find(roots.Emotes,"display");local emoteOpen=false
    if emoteDisplay then emoteDisplay.Position=UDim2.new(0.5,0,1.3,0)end
    bind(find(find(roots.Emotes,"button"),"ImageButton"),function()
        emoteOpen=not emoteOpen
        tween(emoteDisplay,0.5,{Position=emoteOpen and UDim2.new(0.5,0,0.6,0)or UDim2.new(0.5,0,1.3,0)})
        ctx.audio:play({key=emoteOpen and "audio/onSFX"or"audio/offSFX"});return true
    end)
    for i,name in ipairs({"Boston Breakdance","Flex","Rat","Akiyama","idk"})do
        local value=tostring(i);local button=find(emoteDisplay,value)
        text(button,name);if button then button.TextScaled=true;button.TextWrapped=true end
        bind(button,function()return ctx.controller:emote(value)end)
    end
    local function remove(character)local e=billboards[character];billboards[character]=nil;if e then e.scope:destroy()end end
    function module:update(state)
        if dash and not ctx.avatars:getLocal()then dash.Visible=false end
        if scope.dead or not state or not state.character or not state.character.Parent then return end
        local character=state.character;local head=character:FindFirstChild("Head");if not head then return end
        local e=billboards[character]
        if not e then
            e={scope=scope:scope()};billboards[character]=e
            e.scope:add(character.AncestryChanged:Connect(function(_,parent)if not parent then remove(character)end end))
            for _,name in ipairs({"stats","Info","society","completionLeader","BillboardGui"})do
                if roots[name]then
                    local gui=roots[name]:Clone();gui.Adornee=head;gui.Parent=ctx.guiParent();e.scope:add(gui);e[name]=gui
                end
            end
        end
        local displayName=state.displayName or character.Name
        text(find(e.stats,"TextLabel"),displayName)
        local label=find(e.Info,"NameText");text(label,displayName);text(find(label,"Background"),displayName)
        local gender=find(e.Info,"GenderText");local colors=genderColors[state.gender]
        text(gender,colors and state.gender or"");text(find(gender,"Background"),colors and state.gender or"")
        if colors and gender then gender.TextColor3=colors[1];local shadow=find(gender,"Background");if shadow then shadow.TextColor3=colors[2]end end
        local health=find(e.stats,"health");local bar=find(health,"Frame")
        local fraction=math.max(0,math.min(1,(state.health or 0)/math.max(1,state.maxHealth or 100)))
        tween(bar,0.15,{Size=UDim2.new(fraction,0,1,0)})
        local name=find(e.stats,"TextLabel");if name then name.TextColor3=state.downed and Color3.fromRGB(255,42,66)or Color3.new(1,1,1)end
        local fun=find(find(e.stats,"fun"),"Frame");if fun then fun.Size=UDim2.new(0,0,1,0)end
        if e.BillboardGui then e.BillboardGui.Enabled=state.ownerTag==true;text(find(e.BillboardGui,"TextLabel"),"OWNER")end
        if e.completionLeader then e.completionLeader.Enabled=false end
        local winner,highest=nil,0
        for _,s in pairs(ctx.state:all())do if (s.kills or 0)>highest then highest=s.kills;winner=s.character end end
        for c,b in pairs(billboards)do if b.society then b.society.Enabled=c==winner end end
        local actor=ctx.avatars:getLocal()
        if not actor or state.character~=actor.character then return end
        if roots.Gender then roots.Gender.Enabled=colors==nil end
        if dash then dash.Visible=colors~=nil and state.weapon~=nil and state.weapon~="" and not state.busy and not state.downed and not state.ragdolled and not state.carrying and not state.carriedBy end
        if selectedWeapon and state.weapon==selectedWeapon and roots.weapon then roots.weapon.Enabled=false;selectedWeapon=nil end
    end
    local hitFrame=find(roots.HitIndicator,"Frame");local hits,damage,hitAt=0,0,0
    if hitFrame then hitFrame.Visible=false end
    scope:add(ctx.network:on("Damage",function(data)
        local actor=ctx.avatars:getLocal()
        if not actor or not data or data.attacker~=actor.character then return end
        if tick()-hitAt>3 then hits,damage=0,0 end
        hitAt=tick();hits=hits+1;damage=damage+(data.amount or 0)
        if hitFrame then hitFrame.Visible=true;text(find(hitFrame,"Hits"),hits);text(find(hitFrame,"Damage"),string.format("%.1f",damage))end
    end))
    scope:add(Input.InputBegan:Connect(function(input,processed)
        if processed or Input:GetFocusedTextBox()then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then ctx.controller:swing()
        elseif input.KeyCode==Enum.KeyCode.Q then ctx.controller:dash()
        elseif input.KeyCode==Enum.KeyCode.Backspace or input.KeyCode==Enum.KeyCode.T then
            local actor=ctx.avatars:getLocal();if actor and actor.carrying then ctx.controller:drop()end
        elseif input.KeyCode==Enum.KeyCode.End then ctx.destroy()
        elseif input.KeyCode==Enum.KeyCode.G then ctx.controller:emote("1")end
    end))
    scope:add(Input.TouchTap:Connect(function(_,processed)if not processed and not Input:GetFocusedTextBox()then ctx.controller:swing()end end))
    local function chat(message)
        if message=="spawn"or message==":dummy"or message==":spawndummy"then ctx.controller:dummy()end
    end
    if player.Chatted then scope:add(player.Chatted:Connect(chat))end
    pcall(function()
        local service=game:GetService("TextChatService")
        scope:add(service.SendingMessage:Connect(function(message)chat(message.Text)end))
    end)
    scope:add(ctx.state:onChanged(function(state)module:update(state)end))
    scope:add(ctx.network:on("Remove",function(data)if data and data.character then remove(data.character)end end))
    local floaters={}
    for _,value in ipairs({{find(roots.title,"TextLabel"),1,50,-5},{find(roots.title,"dis"),1,75,-5},{find(roots.title,"disc"),1,100,-5},{find(roots.Emotes,"button"),1.3,10,-2},{hitboxButton,1.7,nil,4}})do
        if value[1]then local o=value[1];floaters[#floaters+1]={object=o,position=o.Position,rotation=o.Rotation,period=value[2]*2,target=value[3],angle=value[4]}end
    end
    local started=tick()
    scope:add(Run.RenderStepped:Connect(function()
        local now=tick()
        for _,e in ipairs(floaters)do
            local alpha=(1-math.cos((now-started)*2*math.pi/e.period))/2;local p=e.position
            if e.target then e.object.Position=UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+(e.target-p.Y.Offset)*alpha)end
            e.object.Rotation=e.rotation+(e.angle-e.rotation)*alpha
        end
        if subtitle and statusUntil>0 and now>statusUntil then subtitle.Text="";statusUntil=0 end
        if hitFrame and hitFrame.Visible and now-hitAt>3 then hitFrame.Visible=false;hits,damage=0,0 end
    end))
    scope:add(function()local objects={};for object in pairs(tweens)do objects[#objects+1]=object end;for _,o in ipairs(objects)do cancel(o)end end)
    for _,state in pairs(ctx.state:all())do module:update(state)end
    function module:destroy()scope:destroy()end
    return module
end
