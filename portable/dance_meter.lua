-- Source meter presentation and inputs for the ordinary-emote dance adapter.
return function(ctx,mobile)
    local scope=ctx.cleanup:scope()
    assert(ctx.catalog.packages['gui/meter'],'Missing original gui/meter package')
    local gui=ctx.assets:clone('gui/meter')
    scope:add(gui)
    if scope.dead then return {destroy=function()end}end
    local frame=assert(gui:FindFirstChild('Frame'),'Original meter Frame is missing')
    local container=assert(frame:FindFirstChild('container'),'Original meter container is missing')
    local bar=assert(container:FindFirstChild('bar'),'Original meter bar is missing')
    local label=assert(gui:FindFirstChild('TextLabel'),'Original meter action label is missing')
    local icon=label:FindFirstChild('ImageLabel')
    local white=gui:FindFirstChild('white');if white then white.Visible=false end
    local button=mobile and mobile:FindFirstChild('R')
    local input=game:GetService('UserInputService')
    gui.ResetOnSpawn=false;gui.Enabled=false;gui.Parent=ctx.guiParent()
    local module={gui=gui}
    local function render()
        if scope.dead then return end
        local view=ctx.core:danceMeterView(ctx.avatars:getLocal())
        gui.Enabled=view~=nil
        bar.Size=UDim2.new(1,0,view and view.progress or 0,0)
        label.Visible=view and view.ready or false
        label.Text=view and view.nextStage==4 and 'R - RELEASE' or 'R - Faster'
        label.TextTransparency=0;label.TextStrokeTransparency=0
        if icon then icon.ImageTransparency=0.6 end
        if button then button.Visible=input.TouchEnabled and view and view.ready or false end
    end
    local function advance()
        if scope.dead then return end
        local view=ctx.core:danceMeterView(ctx.avatars:getLocal())
        if not view or not view.ready then return end
        local ok,why=ctx.controller:advanceDance()
        if not ok then ctx.report(tostring(why))end
        render()
    end
    scope:add(ctx.core:onChanged(render))
    scope:add(input.InputBegan:Connect(function(key,processed)
        if not processed and key.KeyCode==Enum.KeyCode.R and not input:GetFocusedTextBox()then advance()end
    end))
    if button and button:IsA('GuiButton')then scope:add(button.Activated:Connect(advance))end
    scope:add(function()if button then button.Visible=false end end)
    render()
    function module:destroy()scope:destroy()end
    return module
end
