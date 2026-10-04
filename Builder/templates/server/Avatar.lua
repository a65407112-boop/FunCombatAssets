-- Original R6 avatar normalization (source 78228), before gameplay binds.
local Players=game:GetService("Players")
local A={}
function A.prepare(player,character,humanoid)
    local done,fetching,complete,cancelled=false,true,false,false
    local failure
    coroutine.wrap(function()
        local ok,description=pcall(function() return Players:GetHumanoidDescriptionFromUserId(player.UserId) end)
        if cancelled or not player.Parent or player.Character~=character or not character.Parent then done=true;return end
        fetching=false
        if ok then
            for _,name in ipairs({"Head","LeftArm","LeftLeg","RightArm","RightLeg","Torso"}) do description[name]=0 end
            local applied,why=pcall(function() humanoid:ApplyDescription(description) end)
            if not applied then failure="Original R6 avatar normalization failed: "..tostring(why) end
        else failure="Original avatar description unavailable: "..tostring(description) end
        complete=true;done=true
    end)()
    local deadline=tick()+8
    repeat wait(0.05) until done or tick()>=deadline or not player.Parent or player.Character~=character or not character.Parent
    if not done then
        cancelled=true
        -- A late fetch cannot mutate an already bound character. An in-flight
        -- engine ApplyDescription may still finish, so do not bind that body.
        return fetching,"Original R6 avatar normalization timed out after 8 seconds" 
    end
    return complete,failure
end
return A
