return function(ctx)
    local scope=ctx.cleanup:scope()
    local Players=game:GetService("Players")
    local Input=game:GetService("UserInputService")
    local Run=game:GetService("RunService")
    local gui=Instance.new("ScreenGui");gui.Name="FunCombatPortableHUD";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;scope:add(gui)
    gui.Parent=ctx.guiParent()
    local frame=Instance.new("Frame");frame.Size=UDim2.new(0,286,0,206);frame.Position=UDim2.new(0,12,0,12)
    frame.BackgroundColor3=Color3.fromRGB(25,29,36);frame.BackgroundTransparency=0.12;frame.BorderSizePixel=0;frame.Parent=gui
    local function label(text,x,y,w,h)
        local t=Instance.new("TextLabel");t.Text=text;t.BackgroundTransparency=1;t.Size=UDim2.new(0,w,0,h);t.Position=UDim2.new(0,x,0,y)
        t.Font=Enum.Font.SourceSans;t.TextSize=16;t.TextColor3=Color3.fromRGB(235,238,244);t.TextWrapped=true;t.Parent=frame;return t
    end
    local function button(text,x,y,w,fn)
        local b=Instance.new("TextButton");b.Text=text;b.Size=UDim2.new(0,w,0,32);b.Position=UDim2.new(0,x,0,y)
        b.Font=Enum.Font.SourceSans;b.TextSize=16;b.TextColor3=Color3.new(1,1,1);b.BackgroundColor3=Color3.fromRGB(55,66,82);b.BorderSizePixel=0;b.Parent=frame
        scope:add(b.Activated:Connect(function()local ok,why=fn();if ok==false and why then ctx.status(why)end end));return b
    end
    label("FUN COMBAT · LOCAL",8,4,234,24)
    button("×",250,2,28,function()ctx.destroy();return true end)
    local weapon=label("Bat",38,35,208,24)
    local function cycle(direction)
        local index=1
        for i,name in ipairs(ctx.catalog.weapons)do if name==ctx.controller.selected then index=i;break end end
        return ctx.controller:equip(ctx.catalog.weapons[(index-1+direction)%#ctx.catalog.weapons+1])
    end
    button("‹",8,32,30,function()return cycle(-1)end);button("›",248,32,30,function()return cycle(1)end)
    button("Attack · click",8,72,132,function()return ctx.controller:swing()end)
    local carry=button("Carry · T",148,72,130,function()
        local a=ctx.avatars:getLocal();if a and a.carrying then return ctx.controller:drop()end
        return ctx.controller:carry()
    end)
    button("Local dummy",8,112,270,function()return ctx.controller:dummy()end)
    local target=label("Hit a nearby target; combo 3 knocks it down",8,148,270,20)
    local status=label("Starting...",8,173,270,27);status.TextSize=13;status.TextColor3=Color3.fromRGB(180,199,220)
    local module={last="Ready",statusUntil=0}
    function module:status(text)self.last=tostring(text);self.statusUntil=tick()+6;status.Text=self.last end
    scope:add(Input.InputBegan:Connect(function(input,processed)
        if processed or Input:GetFocusedTextBox() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then ctx.controller:swing()
        elseif input.KeyCode==Enum.KeyCode.T then
            local a=ctx.avatars:getLocal();if a and a.carrying then ctx.controller:drop()end
        else
            local keys={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six}
            for i,key in ipairs(keys)do if input.KeyCode==key then ctx.controller:equip(ctx.catalog.weapons[i]);break end end
        end
    end))
    scope:add(Run.Heartbeat:Connect(function()
        weapon.Text=ctx.controller.selected..(ctx.controller.loading and " ..." or "")
        local a=ctx.avatars:getLocal()
        carry.Text=a and a.carrying and "Drop · T" or "Carry · T"
        local v=a and (a.carrying or ctx.avatars:nearest(true))
        target.Text=v and (v.displayName.." · local downed target")or"Combo 3 knocks down a nearby target"
        if tick()>module.statusUntil then status.Text="Only you see this · local hits: "..tostring(a and a.hits or 0)end
    end))
    function module:destroy()scope:destroy()end
    return module
end
