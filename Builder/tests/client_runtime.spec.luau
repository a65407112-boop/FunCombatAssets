-- This header is combined with the real client factories by run_client_tests.py.
local currentTime=100
local function tick() return currentTime end
local function wait(seconds) currentTime=currentTime+(seconds or 0.05) end
local function typeof(object) return type(object)=="table" and object.kind or type(object) end
local function signal()
    local handlers={}
    local value={}
    function value:Connect(callback)
        handlers[callback]=true
        return {Disconnect=function() handlers[callback]=nil end}
    end
    function value:fire(...) for fn in pairs(handlers) do fn(...) end end
    return value
end
local function maid()
    local value={items={},dead=false}
    function value:add(item) self.items[#self.items+1]=item;return item end
    function value:scope() local child=maid();self:add(child);return child end
    function value:destroy()
        self.dead=true
        for _,item in ipairs(self.items) do
            if type(item)=="function" then item() elseif item.Disconnect then item:Disconnect() elseif item.destroy then item:destroy() end
        end
    end
    return value
end
local function instance(class,name)
    local obj={kind="Instance",class=class,Name=name,children={}}
    function obj:IsA(cls) return self.class==cls end
    function obj:FindFirstChild(n) return self.children[n] end
    return obj
end
local root=instance("Folder","RS")
local folder=instance("Folder","nfolder");root.children.nfolder=folder
local action=instance("RemoteEvent","naction");folder.children.naction=action
local event=instance("RemoteEvent","nevent");folder.children.nevent=event;event.OnClientEvent=signal()
local snapshot=instance("RemoteFunction","nsnapshot");folder.children.nsnapshot=snapshot
local version=instance("IntValue","nversion");folder.children.nversion=version;version.Value=4
local build=instance("StringValue","nbuild");folder.children.nbuild=build;build.Value="test-build"
local player={Character=instance("Model","Actor")}
local game={GetService=function(_,name) if name=="ReplicatedStorage" then return root elseif name=="Players" then return {LocalPlayer=player} end;error(name) end}
local protocol={version=4,buildId="test-build",names={Folder="nfolder",Action="naction",Presentation="nevent",Snapshot="nsnapshot",Version="nversion",BuildId="nbuild"},
    actionIds={Swing="encoded-swing"},eventIds={State="encoded-state",Remove="encoded-remove",Effect="encoded-effect"}}
local ctx={protocol=protocol,manifest={buildId="test-build"},cleanup=maid(),report=function(why) error(why) end}
local fired={}
function action:FireServer(id,payload) fired[#fired+1]={id,payload} end
function snapshot:InvokeServer() return {version=4,buildId="test-build",ready=true,serverTime=currentTime-0.4,clockTime=currentTime,states={}} end
