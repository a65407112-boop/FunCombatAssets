"""Exercise original resource reconstruction with native CSG and no executor file loader.

Only engine APIs are doubled. These checks do not inspect or simulate geometry.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = 'local cleanupFactory, assetsFactory\n'
code += (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
for name in ['cleanup', 'assets']:
    code += '\n' + name + 'Factory=(function()\n' + (ROOT / 'client' / (name + '.lua')).read_text() + '\nend)()\n'
code += r'''
local replicated=node('Folder','ReplicatedStorage')
local baseService=game.GetService
game.GetService=function(self,name) if name=='ReplicatedStorage' then return replicated else return baseService(self,name) end end
function methods:WaitForChild(name,timeout)
    local deadline=tick()+timeout
    repeat local value=self:FindFirstChild(name);if value then return value end;wait(0.05) until tick()>=deadline
end
function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
local fixture={version=1,root=1,externalReferences={},nodes={
    {id=1,class='Model',name='TorsoRig',properties={}},
    {id=2,class='Part',name='ref',parent=1,properties={}},
    {id=3,class='UnionOperation',name='skin',parent=2,properties={Transparency={type='number',value=0.25}}},
    {id=4,class='Weld',name='OriginalJoint',parent=2,properties={Part0={type='Ref',value=2},Part1={type='Ref',value=3}}}
}}
local function prepare(native)
    replicated:ClearAllChildren()
    local ctx=context();ctx.catalog.packages['costumes/TorsoRig']={path='original-model-json',modelPath='original-model-xml',count=4,backend='model'}
    ctx.catalog.nativeCSG={folder='EncodedNativeDependency',nodes={['3']='EncodedOriginalUnion'}}
    function ctx.json(path) assert(path=='original-model-json','Unexpected resource fetch');return fixture end
    if native then
        local folder=node('Folder','EncodedNativeDependency');folder.Parent=replicated
        local union=node('UnionOperation','EncodedOriginalUnion');union.nativePayload='unchanged-original-binary-csg';union.Parent=folder
    end
    ctx.assets=assetsFactory(ctx);return ctx
end
local failed,total={},0
local function check(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then print('Native assets: '..name) else failed[#failed+1]=name..': '..tostring(why);print('FAIL '..failed[#failed]) end
end
check('original costume restores without local GetObjects and preserves real CSG payload',function()
    local ctx=prepare(true)
    local model=ctx.assets:construct(fixture,'costumes/TorsoRig')
    local ref=model:FindFirstChild('ref');local union=ref:FindFirstChild('skin');local weld=ref:FindFirstChild('OriginalJoint')
    assert(union.ClassName=='UnionOperation' and union.nativePayload=='unchanged-original-binary-csg','Original CSG was replaced')
    assert(union.Name=='skin' and union.Transparency==0.25,'External resource properties were not restored')
    assert(weld.Part0==ref and weld.Part1==union,'External model references were not restored')
    assert(replicated:FindFirstChild('EncodedNativeDependency'):FindFirstChild('EncodedOriginalUnion').Transparency~=0.25,'Native template was mutated')
    model:Destroy();ctx.cleanup:destroy()
end)
check('model package uses native reconstruction before unsupported executor deserialization',function()
    local ctx=prepare(true);local model=ctx.assets:clone('costumes/TorsoRig')
    assert(model:FindFirstChild('ref'):FindFirstChild('skin').nativePayload=='unchanged-original-binary-csg')
    model:Destroy();ctx.cleanup:destroy()
end)
check('missing native dependency times out and names its exact path',function()
    local ctx=prepare(false);local started=tick();local ok,why=pcall(ctx.assets.clone,ctx.assets,'costumes/TorsoRig')
    assert(not ok and tostring(why):find('EncodedNativeDependency') and tick()-started<=1.1,'Missing native dependency was hidden or unbounded')
    ctx.cleanup:destroy()
end)
check('wrong native class is rejected before constructing a substitute',function()
    local ctx=prepare(true);local folder=replicated:FindFirstChild('EncodedNativeDependency');folder:ClearAllChildren()
    local part=node('Part','EncodedOriginalUnion');part.Parent=folder
    local ok,why=pcall(ctx.assets.clone,ctx.assets,'costumes/TorsoRig')
    assert(not ok and tostring(why):find('UnionOperation'),'A different native resource was accepted as original CSG')
    ctx.cleanup:destroy()
end)
assert(#failed==0,table.concat(failed,'\n'))
print('Native asset scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'native-assets.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
