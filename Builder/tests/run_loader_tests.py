"""Run the real loader bootstrap with HTTP/UI doubles; no executor or engine claims."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import zlib

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--luau',required=True);args=parser.parse_args()

def lua(value):
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,(int,float)):return repr(value)
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    raise TypeError(type(value))

protocol_version=json.loads((ROOT/'config/protocol.json').read_text())['version']
reason='Original resource warm-up failed: asset costumes/TorsoRig: '+'original-resource-detail-'*30+'END-OF-EXACT-ERROR'
files={'config/assets.json':'assets','config/identifiers.json':'identifiers','config/protocol.json':'protocol',
       'client/failure.lua':'return function(ctx) error('+lua(reason)+') end'}
manifest={'project':'FunCombat_ExecutorSide_Combat','protocolVersion':protocol_version,'buildId':'fixture','sourceSha256':'fixture',
          'modules':['failure'],'dependencies':{'failure':[]},
          'files':{k:{'bytes':len(v.encode()),'adler32':zlib.adler32(v.encode())&0xffffffff} for k,v in files.items()}}
fixtures={'manifest':manifest,'assets':{'sourceSha256':'fixture'},'identifiers':{},'protocol':{'version':protocol_version,'buildId':'fixture'}}
code=r'''
local now=100
local function tick() return now end
local function wait(seconds) now+=seconds or 0.05 end
local environment={}
local function getgenv() return environment end
local nodes={}
local function signal()
    local callbacks={}
    return {Connect=function(_,fn) callbacks[fn]=true;return {Disconnect=function() callbacks[fn]=nil end} end,
        fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end}
end
local methods={}
function methods:FindFirstChildOfClass(cls) for _,n in ipairs(nodes) do if n.Parent==self and n.ClassName==cls then return n end end end
function methods:GetPropertyChangedSignal() return signal() end
function methods:Destroy() self.destroyed=true;self.Parent=nil;for _,n in ipairs(nodes) do if n.Parent==self then n:Destroy() end end end
local Instance={new=function(class)
    local obj=setmetatable({ClassName=class,MouseButton1Click=signal(),AbsoluteSize={X=600,Y=300}},{__index=methods})
    nodes[#nodes+1]=obj;return obj
end}
local UDim2={new=function(...) return {...} end}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={fromRGB=function(...) return {...} end}
local Enum={Font={Code=1,SourceSansBold=2,SourceSans=3},TextXAlignment={Left=1},TextYAlignment={Top=1}}
local playerGui=Instance.new('PlayerGui')
local player=Instance.new('Player');playerGui.Parent=player
local services={Players={LocalPlayer=player},CoreGui=Instance.new('CoreGui'),
    StarterGui={SetCore=function() end},TextService={GetTextSize=function(_,message) return {Y=#message} end}}
local copied
local function setclipboard(value) copied=value end
local function warn() end
local files,fixtures,reason
local httpFailure=false
local request=function(options)
    local path=options.Url:match('/main/(.*)$')
    if httpFailure then return {StatusCode=403,Body='Forbidden'} end
    return {StatusCode=200,Body=path=='manifest.json' and 'manifest' or files[path]}
end
local game={GetService=function(_,name) assert(services[name],'Unexpected service '..name);return services[name] end}
services.HttpService={JSONDecode=function(_,data) return assert(fixtures[data],'Missing JSON fixture '..tostring(data)) end}
'''
code+='\nfiles='+lua(files)+'\nfixtures='+lua(fixtures)+'\nreason='+lua(reason)+'\n'
code+='local function runLoader()\n'+(ROOT/'loader.lua').read_text()+'\nend\n'
code+=r'''
local function details(gui)
    for _,n in ipairs(nodes) do if n.ClassName=='TextBox' and not n.destroyed then return n end end
end
local ok,why=pcall(runLoader)
assert(not ok and tostring(why):find('END%-OF%-EXACT%-ERROR'),'Original failure was not reproduced')
local first=environment.FunCombat_ExternalRuntime_ErrorGUI
assert(first and details(first) and details(first).Text:find(reason,1,true),'Full error was not available in a readable error window')
local copy
for _,n in ipairs(nodes) do if n.Name=='Copy' and not n.destroyed then copy=n end end
assert(copy,'Error cannot be copied');copy.MouseButton1Click:fire();assert(copied:find(reason,1,true),'Copy lost the exact error suffix')
print('Loader: full bootstrap resource error is visible and copyable')
ok=pcall(runLoader)
local second=environment.FunCombat_ExternalRuntime_ErrorGUI
assert(not ok and first.destroyed and second~=first,'Reexecution accumulated duplicate failure windows')
print('Loader: reexecution replaces the old failure window')
httpFailure=true
ok,why=pcall(runLoader)
assert(not ok and second.destroyed and details(environment.FunCombat_ExternalRuntime_ErrorGUI).Text:find('HTTP 403',1,true),
    'A failure before manifest download required external UI resources or lost its status')
print('Loader: pre-manifest HTTP errors remain readable without downloads')
httpFailure=false
fixtures.manifest.modules={};fixtures.manifest.dependencies={}
local last=environment.FunCombat_ExternalRuntime_ErrorGUI
ok,why=pcall(runLoader)
assert(ok and why.initialized and last.destroyed and environment.FunCombat_ExternalRuntime_ErrorGUI==nil,'A successful rerun retained the failure window')
print('Loader: successful rerun clears previous diagnostics; 4 scenarios passed')
'''
with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
    path=Path(tmp)/'loader.luau';path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
