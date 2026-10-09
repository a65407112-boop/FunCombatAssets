"""Test actual local scoreboard labels across late joins and repeated loaders."""
import argparse, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);args=p.parse_args()
code=(ROOT/'Builder/tests/presentation_runtime.spec.luau').read_text()
code+='\nlocal Cleanup=(function()\n'+(ROOT/'client/cleanup.lua').read_text()+'\nend)()\n'
code+='\nlocal Labels=(function()\n'+(ROOT/'client/labels.lua').read_text()+'\nend)()\n'
code+=r'''
function methods:GetPropertyChangedSignal(name)
    self.signals=self.signals or {};self.signals[name]=self.signals[name] or signal();return self.signals[name]
end
local function observed(class,name)
    local n=node(class,name);local mt=getmetatable(n);local assign=mt.__newindex
    mt.__newindex=function(self,key,value)
        assign(self,key,value)
        if self.signals and self.signals[key] then self.signals[key]:fire() end
    end
    return n
end
local first=observed('Player','First');first.Parent=true
local service={PlayerAdded=signal(),all={first}}
function service:GetPlayers() return self.all end
game.GetService=function(_,name) assert(name=='Players');return service end
local ctx={identifiers={stats={Kills='opaque_kills',Completions='opaque_completions'}}}
ctx.cleanup=Cleanup(ctx)
local module=Labels(ctx)
local stats=observed('Folder','leaderstats');stats.Parent=first
local kills=observed('IntValue','opaque_kills');kills.Value=3;kills.Parent=stats
assert(kills.Name=='Kills' and kills.Value==3,'Late stat was not labeled or its value was changed')
local later=observed('Player','Later');later.Parent=true;service.all[#service.all+1]=later;service.PlayerAdded:fire(later)
local lateStats=observed('Folder','leaderstats');lateStats.Parent=later
local done=observed('IntValue','opaque_completions');done.Parent=lateStats
assert(done.Name=='Completions','Late player did not receive the normal stat label')
module:destroy()
assert(kills.Name=='opaque_kills' and done.Name=='opaque_completions','Cleanup failed to restore server names before rerunning the loader')
local nextCtx={identifiers=ctx.identifiers};nextCtx.cleanup=Cleanup(nextCtx)
local nextModule=Labels(nextCtx);assert(kills.Name=='Kills' and done.Name=='Completions','Rerun duplicated or lost local labels')
nextModule:destroy()
print('Labels: late stats, late players, unchanged values, cleanup and reexecution passed')
'''
with tempfile.TemporaryDirectory(dir=ROOT.parent) as d:
 f=Path(d)/'labels.luau';f.write_text(code);subprocess.run([str(Path(args.luau).resolve()),str(f)],check=True)
