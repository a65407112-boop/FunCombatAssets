-- Manual, reversible comparison for the reported black dynamic head.
-- The normal loader does not execute this script. It tests ONE variable:
-- original RGBA face pixels over the original Head.Color via native Overlay.
-- No geometry, joints, FaceControls, animation or avatar color is changed.
local SOURCE_TEXTURE = "rbxassetid://130652123696339"
local SOURCE_PNG_SHA = "72bde92df1de980578edbb21f40858771ea7d4cb215a68cd24627d6e4b88e461"
local RGBA_SHA = "cd67ba43010b8d05a72a95134620a7f7e829bbd67f535a58f7715fc7fdef9e1e"
local RGBA_ADLER = 4278240354
local RESOURCE = "diagnostics/head_texture_130652123696339.json"
local environment = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then environment = value end
end
local slot = "FunCombat_HeadTextureTest"
local previous = environment[slot]
if type(previous) == "table" and type(previous.destroy) == "function" then pcall(function() previous:destroy() end) end
local players, http = game:GetService("Players"), game:GetService("HttpService")
local player = players.LocalPlayer
local character = player and player.Character
local head = character and character:FindFirstChild("Head")
local session = {report = {sourceTexture = SOURCE_TEXTURE, sourcePngSha256 = SOURCE_PNG_SHA,
    rgbaSha256 = RGBA_SHA, stage = "ready", renderVerified = false, visualObservation = "not reported"}}
environment[slot] = session
local surface, image, sequence, busy, closed, expired = nil, nil, 0, false, false, false
local connections = {}
local status, details
local function discard(object) if object then pcall(function() object:Destroy() end) end end
local function snapshot()
    local result = {missing = not head}
    if head then
        for _, key in ipairs({"ClassName", "TextureID", "MeshId", "Transparency"}) do
            local ok, value = pcall(function() return head[key] end)
            if ok then result[key] = value end
        end
        pcall(function() result.Color = {R=head.Color.R,G=head.Color.G,B=head.Color.B} end)
        pcall(function() result.FaceControls = head:FindFirstChildOfClass("FaceControls") ~= nil end)
    end
    return result
end
session.report.before = snapshot()
local function reportText()
    local ok, text = pcall(function() return http:JSONEncode(session.report) end)
    return ok and text or "JSON unavailable: " .. tostring(text) .. "\n" .. tostring(session.report.error or session.report.stage)
end
local function refresh(message)
    if closed then return end
    if status then status.Text = message end
    if details then details.Text = reportText() end
end
local function restore()
    sequence += 1; busy = false
    discard(surface); surface = nil
    discard(image); image = nil
    session.report.stage = "restored"
    session.report.after = snapshot()
    refresh("Original appearance restored. Copy report keeps the comparison result.")
end
function session:destroy()
    if closed then return end
    restore(); closed = true
    for _, connection in ipairs(connections) do connection:Disconnect() end
    connections = {}
    discard(self.gui)
    if environment[slot] == self then environment[slot] = nil end
end
local function valid(token)
    return not closed and not expired and sequence == token and player and player.Character == character
        and character and character.Parent and head and head.Parent == character and character:FindFirstChild("Head") == head
end
local function validateHead(token)
    assert(valid(token) and head:IsA("MeshPart") and head:FindFirstChildOfClass("FaceControls"), "No current native dynamic MeshPart head is available")
    local texture = tostring(head.TextureID)
    local id = texture:match("id=(%d+)") or texture:match("(%d+)$")
    assert(id=="130652123696339", "Avatar texture changed: " .. texture .. ". This test will not substitute a different face")
    assert(not head:FindFirstChildOfClass("SurfaceAppearance"), "The head already has a SurfaceAppearance; it will not be overwritten")
end
local function bounded(label, seconds, token, operation, dispose)
    local done, accepted, abandoned, result, failure = false, false, false, nil, nil
    task.spawn(function()
        local ok, value = pcall(operation)
        if abandoned or not valid(token) then
            if ok and dispose then dispose(value) end
        else
            accepted = ok; if ok then result = value else failure = value end
        end
        done = true
    end)
    local deadline = tick() + seconds
    while not done and valid(token) and tick() < deadline do task.wait(0.05) end
    if not done then
        abandoned = true
        error(label .. (valid(token) and " timed out after " .. seconds .. " seconds" or " cancelled"))
    end
    if not valid(token) then
        if accepted and dispose then dispose(result) end
        error(label .. " cancelled")
    end
    assert(accepted, label .. ": " .. tostring(failure))
    return result
end
local function integer(value, low, high)
    return type(value)=="number" and value==value and value%1==0 and value>=low and value<=high
end
local function pixels(document)
    assert(type(document)=="table" and document.schema==1 and document.format=="rgba-u32le-rle", "Unsupported face pixel schema")
    assert(document.sourceTexture==SOURCE_TEXTURE and document.sourcePngSha256==SOURCE_PNG_SHA
        and document.rgbaSha256==RGBA_SHA, "This resource does not match the verified original face")
    assert(document.width==512 and document.height==512, "Original face dimensions differ; resizing is not permitted")
    assert(type(document.runs)=="table" and #document.runs>0 and #document.runs<=262144, "Invalid face pixel runs")
    local total = 0
    for _, run in ipairs(document.runs) do
        assert(type(run)=="table" and #run==2 and integer(run[1],1,262144) and integer(run[2],0,4294967295), "Invalid RGBA run")
        total += run[1]; assert(total<=262144, "Face pixel runs overflow the original image")
    end
    assert(total==262144, "Face pixel resource is incomplete")
    local data, offset = buffer.create(1048576), 0
    for _, run in ipairs(document.runs) do
        for _=1,run[1] do buffer.writeu32(data,offset,run[2]); offset+=4 end
    end
    local bytes, a, b = buffer.tostring(data), 1, 0
    for index=1,#bytes do a=(a+string.byte(bytes,index))%65521; b=(b+a)%65521 end
    assert(b*65536+a==RGBA_ADLER, "Original RGBA checksum differs; no recolored face will be applied")
    return data
end
local function repositoryURL()
    -- Reuse the ONE repository configuration already used by loader.lua.
    local ctx = environment.FunCombat_ExternalRuntime
    assert(type(ctx)=="table" and ctx.initialized and not ctx.cancelled, "Run the normal Fun Combat loader before this test")
    local config = ctx.config
    assert(type(config)=="table", "The active loader has no repository configuration")
    for _, key in ipairs({"Owner","Repository","Branch"}) do
        assert(type(config[key])=="string" and #config[key]>0 and #config[key]<=200
            and config[key]:match("^[%w%._%-%/]+$") and not config[key]:find("..",1,true), "Invalid loader repository setting: " .. key)
    end
    return "https://raw.githubusercontent.com/" .. config.Owner .. "/" .. config.Repository .. "/" .. config.Branch .. "/" .. RESOURCE
end
local function compare()
    if closed or busy then return end
    if expired then refresh("Character changed. Run this separate test again for the new character."); return end
    if surface then refresh("Test is already applied. Choose the visual result, or Restore."); return end
    sequence += 1; local token=sequence; busy=true
    session.report.error=nil; session.report.stage="testing"; session.report.visualObservation="not reported"
    refresh("Testing original texture alpha. Native calls have finite timeouts.")
    local ok, why = pcall(function()
        validateHead(token)
        assert(type(buffer)=="table" and type(buffer.create)=="function" and type(buffer.writeu32)=="function"
            and type(buffer.tostring)=="function" and type(Content)=="table" and type(Content.fromObject)=="function",
            "This client lacks buffer or Content.fromObject; the original appearance is retained")
        local asset = game:GetService("AssetService")
        assert(type(asset.CreateEditableImage)=="function" and type(asset.CreateSurfaceAppearanceAsync)=="function",
            "This client lacks CreateEditableImage/CreateSurfaceAppearanceAsync; the original appearance is retained")
        local url=repositoryURL(); session.report.resourceURL=url
        local body=bounded("Original pixel download",15,token,function() return game:HttpGet(url) end)
        assert(type(body)=="string" and #body>0 and #body<=600000, "Original pixel download is empty or exceeds 600000 bytes")
        local data=pixels(http:JSONDecode(body)); session.report.pixelChecksum=RGBA_ADLER
        assert(valid(token), "Character changed during resource decoding")
        image=asset:CreateEditableImage({Size=Vector2.new(512,512)})
        assert(image, "CreateEditableImage returned nil: editable image budget/API is unavailable")
        image:WritePixelsBuffer(Vector2.new(0,0),Vector2.new(512,512),data)
        local native=bounded("Native surface processing",10,token,function()
            return asset:CreateSurfaceAppearanceAsync({ColorMap=Content.fromObject(image)})
        end,discard)
        assert(native, "Native surface processing returned no SurfaceAppearance")
        surface=native
        -- Creation does not prove rendering. The user's A/B observation is
        -- deliberately separate from native API and checksum success.
        surface.Name="FunCombatHeadTextureComparison"
        surface.AlphaMode=Enum.AlphaMode.Overlay
        validateHead(token)
        surface.Parent=head
    end)
    if sequence~=token or closed then return end
    busy=false
    if not ok then
        discard(surface);surface=nil;discard(image);image=nil
        session.report.stage="failed";session.report.error=tostring(why)
        refresh("Test unavailable: " .. tostring(why) .. ". Copy report includes the exact error.")
    else
        session.report.stage="applied";session.report.after=snapshot()
        refresh("Look at the face. Choose Looks correct or Still wrong, then Copy report. Restore undoes the test.")
    end
end
local gui
local mounted, uiError = pcall(function()
    gui=Instance.new("ScreenGui");gui.Name="FunCombat_HeadTextureTest";gui.ResetOnSpawn=false
    pcall(function() gui.DisplayOrder=100001 end)
    session.gui=gui
    local frame=Instance.new("Frame");frame.Size=UDim2.new(0.94,0,0,250);frame.Position=UDim2.new(0.03,0,1,-264)
    frame.BackgroundColor3=Color3.fromRGB(24,24,30);frame.BorderSizePixel=0;frame.Parent=gui
    local title=Instance.new("TextLabel");title.Size=UDim2.new(1,-90,0,30);title.Position=UDim2.new(0,10,0,0)
    title.Text="Original face texture comparison";title.BackgroundTransparency=1;title.TextColor3=Color3.fromRGB(245,245,245)
    title.Font=Enum.Font.SourceSansBold;title.TextSize=18;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=frame
    local function button(name,text,x,y,width,callback)
        local object=Instance.new("TextButton");object.Name=name;object.Text=text
        object.Size=UDim2.new(width,-8,0,32);object.Position=UDim2.new(x,4,0,y)
        object.Font=Enum.Font.SourceSansBold;object.TextSize=16;object.Parent=frame
        object.MouseButton1Click:Connect(callback);return object
    end
    local close=Instance.new("TextButton");close.Name="Close";close.Text="Close"
    close.Size=UDim2.new(0,64,0,24);close.Position=UDim2.new(1,-70,0,3);close.Parent=frame
    close.MouseButton1Click:Connect(function() session:destroy() end)
    button("Test","Test texture",0,34,1/3,compare)
    button("Restore","Restore",1/3,34,1/3,restore)
    button("Copy","Copy report",2/3,34,1/3,function()
        local text=reportText()
        local clipboard=setclipboard
        if type(clipboard)~="function" then clipboard=toclipboard end
        if type(clipboard)~="function" and type(syn)=="table" then clipboard=syn.write_clipboard end
        local ok,why=false,nil
        if type(clipboard)=="function" then ok,why=pcall(clipboard,text) end
        if ok then refresh("Copied. Paste this comparison report into chat.")
        else
            details.Text=text
            pcall(function() details:CaptureFocus();details.SelectionStart=1;details.CursorPosition=#text+1 end)
            status.Text=(why and "Clipboard failed: "..tostring(why):sub(1,120)..". " or "Clipboard unavailable. ").."Select the report and copy manually."
        end
    end)
    local function observe(value)
        if surface and session.report.stage=="applied" then
            session.report.visualObservation=value;refresh("Visual result recorded. Copy report, then Restore to compare with the original.")
        else refresh("Press Test texture before reporting a visual result.") end
    end
    button("Good","Looks correct",0,70,0.5,function() observe("user reports correct with original alpha overlay") end)
    button("Bad","Still wrong",0.5,70,0.5,function() observe("user reports still wrong with original alpha overlay") end)
    status=Instance.new("TextLabel");status.Size=UDim2.new(1,-16,0,54);status.Position=UDim2.new(0,8,0,106)
    status.BackgroundTransparency=1;status.TextWrapped=true;status.TextColor3=Color3.fromRGB(235,235,240)
    status.Font=Enum.Font.SourceSans;status.TextSize=16;status.TextXAlignment=Enum.TextXAlignment.Left;status.Parent=frame
    local scroll=Instance.new("ScrollingFrame");scroll.Size=UDim2.new(1,-16,0,78);scroll.Position=UDim2.new(0,8,0,166)
    scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.CanvasSize=UDim2.new(0,0,0,1000);scroll.Parent=frame
    details=Instance.new("TextBox");details.Size=UDim2.new(1,-16,0,1000);details.ClearTextOnFocus=false
    details.MultiLine=true;details.TextWrapped=true;details.BackgroundTransparency=1;details.TextColor3=Color3.fromRGB(225,225,230)
    details.Font=Enum.Font.SourceSans;details.TextSize=14;details.TextXAlignment=Enum.TextXAlignment.Left
    details.TextYAlignment=Enum.TextYAlignment.Top;details.Parent=scroll
    local parents={}
    local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
    if playerGui then parents[#parents+1]=playerGui end
    if type(gethui)=="function" then local ok,parent=pcall(gethui);if ok and parent then parents[#parents+1]=parent end end
    local ok,core=pcall(function() return game:GetService("CoreGui") end);if ok then parents[#parents+1]=core end
    local attached,lastError=false,"No permitted GUI parent"
    for _,parent in ipairs(parents) do
        local good,why=pcall(function() gui.Parent=parent end)
        if good then attached=true;break else lastError=tostring(why) end
    end
    assert(attached,lastError)
    refresh("Manual test only. Press Test texture to compare the original face alpha; Restore and Close undo it.")
end)
if not mounted then
    session.report.stage="failed";session.report.error="Comparison window unavailable: "..tostring(uiError)
    session:destroy();warn("[Fun Combat Head Test] "..session.report.error);return session.report
end
if head then
    local function expireIfChanged()
        if not closed and not expired and (not character.Parent or not head.Parent
            or head.Parent~=character or player.Character~=character) then
            restore();expired=true;session.report.stage="expired"
            refresh("Character changed. The temporary texture was removed. Copy report is still available.")
        end
    end
    connections[#connections+1]=head.AncestryChanged:Connect(expireIfChanged)
    connections[#connections+1]=player:GetPropertyChangedSignal("Character"):Connect(expireIfChanged)
end
return session
