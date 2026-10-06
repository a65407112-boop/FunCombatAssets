"""Exercise original resource reconstruction with native CSG and no executor file loader.

Only engine APIs are doubled. These checks do not inspect or simulate geometry.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Builder'))
from build import lua
parser = argparse.ArgumentParser()
parser.add_argument('--luau', required=True)
args = parser.parse_args()
code = 'local cleanupFactory, assetsFactory\n'
code += (ROOT / 'Builder/tests/presentation_runtime.spec.luau').read_text()
code += r'''
-- Datatype constructors are engine boundary doubles. Their payloads are copied,
-- never interpreted as or checked against model geometry.
local function datatype(kind) return {new=function(...) return {kind=kind,values={...}} end} end
local Color3={new=function(r,g,b) return {kind='Color3',R=r,G=g,B=b} end}
local Vector2=datatype('Vector2')
local PhysicalProperties=datatype('PhysicalProperties')
local NumberRange=datatype('NumberRange')
local NumberSequenceKeypoint=datatype('NumberSequenceKeypoint')
local NumberSequence=datatype('NumberSequence')
local ColorSequenceKeypoint=datatype('ColorSequenceKeypoint')
local ColorSequence=datatype('ColorSequence')
'''
for name in ['cleanup', 'assets']:
    code += '\n' + name + 'Factory=(function()\n' + (ROOT / 'client' / (name + '.lua')).read_text() + '\nend)()\n'
catalog=json.loads((ROOT/'config/assets.json').read_text())
originals={key:json.loads((ROOT/catalog['packages'][key]['path']).read_text()) for key in ['costumes/LowerRig','costumes/TorsoRig']}
code+='\nlocal originals='+lua(originals)+'\nlocal originalNative='+lua(catalog['nativeCSG'])+'\n'
code += r'''
local replicated=node('Folder','ReplicatedStorage')
local baseService=game.GetService
game.GetService=function(self,name) if name=='ReplicatedStorage' then return replicated else return baseService(self,name) end end
function methods:WaitForChild(name,timeout)
    local deadline=tick()+timeout
    repeat local value=self:FindFirstChild(name);if value then return value end;wait(0.05) until tick()>=deadline
end
function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
-- The earlier generic node double accepted hidden serialized member names,
-- unlike a real Roblox WeldConstraint. Keep that engine boundary strict.
local newInstance=Instance.new
Instance.new=function(class,...)
    local object=newInstance(class,...)
    if class=='WeldConstraint' then
        local mt=getmetatable(object);local assign=mt.__newindex
        mt.__newindex=function(self,key,value)
            assert(key~='Part0Internal' and key~='Part1Internal',key..' is not a valid member of WeldConstraint')
            assign(self,key,value)
        end
    end
    return object
end
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
check('serialized original WeldConstraint endpoints restore through public Part0 and Part1',function()
    local ctx=prepare(true)
    local data={version=1,root=1,nodes={
        {id=1,class='Model',name='TorsoRig',properties={}},
        {id=2,class='Part',name='ref',parent=1,properties={}},
        {id=3,class='Part',name='Accent',parent=1,properties={}},
        {id=4,class='WeldConstraint',name='WeldConstraint',parent=2,properties={
            Part0Internal={type='Ref',value=2},Part1Internal={type='Ref',value=3}}}
    }}
    local model=ctx.assets:construct(data,'costumes/TorsoRig')
    local a=model:FindFirstChild('ref');local b=model:FindFirstChild('Accent');local weld=a:FindFirstChild('WeldConstraint')
    assert(weld.Part0==a and weld.Part1==b,'Original weld endpoints were dropped or swapped')
    assert(data.nodes[4].properties.Part0Internal.value==2,'Input reference data was mutated')
    model:Destroy();ctx.cleanup:destroy()
end)
for _,key in ipairs({'costumes/LowerRig','costumes/TorsoRig'}) do
    check('complete original '..key..' restores every Instance and real joint endpoints',function()
        replicated:ClearAllChildren()
        local folder=node('Folder',originalNative.folder);folder.Parent=replicated
        for id,name in pairs(originalNative.nodes) do
            local union=node('UnionOperation',name);union.nativePayload='opaque-original-'..id;union.Parent=folder
        end
        local ctx=context();ctx.catalog.nativeCSG=originalNative
        ctx.assets=assetsFactory(ctx)
        local data=originals[key];local model=ctx.assets:construct(data,key)
        assert(#model:GetDescendants()+1==#data.nodes,'Original costume membership changed')
        local joints,unbound=0,0
        for _,object in ipairs(model:GetDescendants()) do
            if object.ClassName=='Weld' or object.ClassName=='Motor6D' then
                joints+=1
                assert(object.Part1,'An original joint lost its nonempty Part1')
                -- These original role attachment motors intentionally have no
                -- Part0 until the costume is attached to a live character.
                local originalUnbound=object.ClassName=='Motor6D' and (object.Name=='LowerRig'
                    or object.Name=='LeftTorsoPanel' or object.Name=='RightTorsoPanel')
                if originalUnbound then
                    unbound+=1;assert(object.Part0==nil,'An original empty endpoint was invented')
                else assert(object.Part0,'An original joint lost its nonempty Part0') end
            end
        end
        if key=='costumes/TorsoRig' then
            assert(#data.nodes==86 and joints==24 and unbound==2,'Original TorsoRig hierarchy changed')
            local ref=assert(model:FindFirstChild('ref'))
            local skin=assert(ref:FindFirstChild('skinTorso'))
            local weld=assert(ref:FindFirstChild('WeldConstraint'))
            assert(weld.Part0==ref and weld.Part1==skin,'Original TorsoRig weld targets differ')
        else
            assert(#data.nodes==58 and joints==20 and unbound==1,'Original LowerRig hierarchy changed')
        end
        model:Destroy();ctx.cleanup:destroy()
    end)
end
assert(#failed==0,table.concat(failed,'\n'))
print('Native asset scenarios passed: '..total)
'''
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path = Path(temporary) / 'native-assets.luau'
    path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()), str(path)], check=True)
