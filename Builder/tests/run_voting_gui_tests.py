"""Exercise the real Voting, GUI and cleanup with the exported GUI hierarchy.

Only Roblox engine APIs are doubled; this does not test rendering in Roblox.
The regression is the server's {name=...} candidates being discarded by GUI.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'


fixtures = {}
for filename in ['gui_MapFrame_d8c9dcca.json', 'gui_MapVoteGui_5fe46380.json']:
    data = json.loads((ROOT / 'assets/gui' / filename).read_text())
    root = next(n for n in data['nodes'] if n['id'] == data['root'])
    # Copy the real hierarchy and observable authored text/visibility metadata.
    fixtures['gui/' + root['name']] = [
        {k: n[k] for k in ['id', 'parent', 'class', 'name']} | {
            'properties': {k: v['value'] for k, v in n['properties'].items()
                           if k in ['Text', 'Visible', 'Enabled', 'Image', 'ImageTransparency', 'LayoutOrder']}}
        for n in data['nodes']]

header = r'''
local cleanupFactory,guiFactory,votingModule
local now=100
local function tick() return now end
local function typeof(v) return type(v)=='table' and v.kind or type(v) end
local function signal()
    local handlers={}
    return {Connect=function(_,fn)
        handlers[fn]=true
        return {kind='RBXScriptConnection',Disconnect=function() handlers[fn]=nil end}
    end,fire=function(_,...) for fn in pairs(handlers) do fn(...) end end}
end
local methods={}
local function node(class,name)
    local object={kind='Instance',props={ClassName=class,Name=name or class,children={},Activated=signal()}}
    return setmetatable(object,{__index=function(_,k) return methods[k] or object.props[k] end,
        __newindex=function(_,k,v)
            local props=object.props
            if k=='Parent' then
                if props.Parent then
                    for i=#props.Parent.children,1,-1 do
                        if props.Parent.children[i]==object then table.remove(props.Parent.children,i) end
                    end
                end
                if v then v.children[#v.children+1]=object end
            end
            props[k]=v
        end})
end
function methods:IsA(class)
    return class==self.ClassName or class=='Instance'
        or (class=='GuiButton' and (self.ClassName=='TextButton' or self.ClassName=='ImageButton'))
end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(self.children) do
        if child.Name==name then return child end
        if recursive then local found=child:FindFirstChild(name,true);if found then return found end end
    end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:Clone()
    local copy=node(self.ClassName,self.Name)
    for k,v in pairs(self.props) do
        if k~='children' and k~='Parent' and k~='Activated' then copy[k]=v end
    end
    for _,child in ipairs(self:GetChildren()) do child:Clone().Parent=copy end
    return copy
end
function methods:Destroy()
    for _,child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent=nil;self.destroyed=true
end
local UDim2={new=function(...) return {...} end}
local Color3={fromRGB=function(...) return {...} end}
local runService={RenderStepped=signal()}
local input={TouchEnabled=false,LastInputTypeChanged=signal()}
local Enum={UserInputType={Touch='Touch'}}
local player=node('Player','Owner');player.CharacterAdded=signal()
player.Parent=node('Folder','Players')
local pg=node('PlayerGui');pg.Parent=player
local players={LocalPlayer=player,GetPlayers=function() return {player} end}
local game={GetService=function(_,name)
    return assert(({Players=players,UserInputService=input,RunService=runService,TweenService={},Lighting={}})[name],name)
end}
local originals={}
for key,list in pairs(fixtureData) do
    local by={};local root
    for _,item in ipairs(list) do
        local v=node(item.class,item.name);by[item.id]=v
        for k,p in pairs(item.properties) do v[k]=p end
    end
    for _,item in ipairs(list) do
        if item.parent then by[item.id].Parent=by[item.parent] else root=by[item.id] end
    end
    originals[key]=root
end
'''
checks = r'''
local reports={}
local ctx={report=function(message) reports[#reports+1]=message end}
ctx.cleanup=cleanupFactory(ctx)
ctx.catalog={packages={['gui/MapFrame']={},['gui/MapVoteGui']={}}}
ctx.assets={clone=function(_,key) return assert(originals[key]):Clone() end}
ctx.audio={play=function() end}
ctx.state={all=function() return {} end,onChanged=function() return function() end end}
local events={}
ctx.network={on=function(_,name,fn) events[name]=fn;return function() events[name]=nil end end}
local gui=guiFactory(ctx)
local frame=assert(gui.roots.MapVoteGui:FindFirstChild('MapVoteFrame'))
local container=assert(frame:FindFirstChild('MapsContainer'))
local maps=node('Folder','Maps');node('Model','Crossroads').Parent=maps;node('Model','BackStreet').Parent=maps
local voting=votingModule.new({emit=function(_,name,data) assert(name=='Voting');events.Voting(data) end},{},maps)
local function rows()
    local result={}
    for _,v in ipairs(container:GetChildren()) do if v:IsA('Frame') then result[#result+1]=v end end
    return result
end
local failures,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Voting GUI: '..name) else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures]) end
end
check('real server candidates create visible original cards',function()
    voting:begin()
    local cards=rows()
    assert(#cards==2,'Server sent two name records, but GUI rendered '..#cards..' map cards')
    assert(frame.Visible and cards[1].Visible and cards[1].Name=='BackStreet' and cards[2].Name=='Crossroads','Cards are hidden, renamed or out of order')
    assert(cards[1]:FindFirstChild('MapName').Text=='BackStreet','Original map label is absent')
    assert(cards[1]:FindFirstChild('NumVotes').Text=='Votes: 0','Initial vote count is absent')
end)
check('clicking a card requests its own server candidate',function()
    local got={};local unsubscribe=gui:onAction(function(action,name) got[#got+1]={action,name} end)
    local cards=rows();assert(#cards==2,'No cards to vote with')
    cards[1]:FindFirstChild('VoteButton').Activated:fire();cards[2]:FindFirstChild('VoteButton').Activated:fire()
    assert(#got==2 and got[1][1]=='Vote' and got[1][2]=='BackStreet' and got[2][2]=='Crossroads','Button captured the wrong name')
    unsubscribe()
end)
check('real server counts update existing cards without duplicate controls',function()
    local old=rows();voting:vote(player,'Crossroads');local cards=rows()
    assert(#cards==2 and cards[1]==old[1] and cards[2]==old[2],'Count update replaced or duplicated controls')
    assert(cards[1]:FindFirstChild('NumVotes').Text=='Votes: 0' and cards[2]:FindFirstChild('NumVotes').Text=='Votes: 1','Server count did not reach labels')
end)
check('late join snapshot renders current counts and countdown',function()
    gui:destroy();gui=guiFactory(ctx);frame=gui.roots.MapVoteGui:FindFirstChild('MapVoteFrame');container=frame:FindFirstChild('MapsContainer')
    gui:updateVoting(voting:state());runService.RenderStepped:fire()
    local cards=rows();assert(#cards==2 and cards[2]:FindFirstChild('NumVotes').Text=='Votes: 1','Late join snapshot lost cards or votes')
    assert(frame:FindFirstChild('Title').Text=='Vote for a map (15)','Server deadline was lost')
end)
check('stale revision cannot erase the current cards',function()
    local old=rows();gui:updateVoting({active=false,candidates={},remaining=0,revision=0})
    assert(frame.Visible and #rows()==2 and rows()[1]==old[1],'Stale event replaced the newer snapshot')
end)
check('ending a vote hides the original window',function()
    voting.active=false;voting:publish();assert(not frame.Visible,'Finished voting window stayed open')
end)
check('changed candidates clean up the previous card and its button',function()
    local old=rows();local emitted=0;gui:onAction(function() emitted+=1 end)
    local oldButton=assert(old[1]:FindFirstChild('VoteButton'))
    gui:updateVoting({active=true,candidates={{name='Crossroads'}},votes={Crossroads=0},revision=99,remaining=15})
    local cards=rows();assert(#cards==1 and cards[1].Name=='Crossroads' and old[1].destroyed,'Old map controls survived a new vote')
    oldButton.Activated:fire()
    assert(emitted==0,'Cleanup emitted a vote')
end)
check('client cleanup removes mounted map UI',function()
    gui:destroy();assert(not pg:FindFirstChild('MapVoteGui'),'Mounted voting GUI survived cleanup')
    assert(#reports==0,table.concat(reports,'\n'))
end)
assert(#failures==0,table.concat(failures,'\n'))
print('Voting GUI regression scenarios passed: '..total)
'''
code = 'local fixtureData=' + lua(fixtures) + '\n' + header
for variable, path in [('cleanupFactory', 'client/cleanup.lua'), ('guiFactory', 'client/gui.lua'),
                       ('votingModule', 'Builder/templates/server/Voting.lua')]:
    code += '\n' + variable + '=(function()\n' + (ROOT / path).read_text() + '\nend)()\n'
code += checks
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'voting_gui.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True, timeout=15)
