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
Enum.MeshType={FileMesh=0}
'''
for name in ['cleanup', 'assets']:
    code += '\n' + name + 'Factory=(function()\n' + (ROOT / 'client' / (name + '.lua')).read_text() + '\nend)()\n'
catalog=json.loads((ROOT/'config/assets.json').read_text())
originals={key:json.loads((ROOT/catalog['packages'][key]['path']).read_text()) for key in ['costumes/LowerRig','costumes/TorsoRig','weapons/Sword','weapons/Maxwell']}
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
local readOnlyMesh=false
local function strict(object)
    if object.ClassName=='MeshPart' or object.ClassName=='SurfaceAppearance' then
        local mt=getmetatable(object);local assign=mt.__newindex
        local lookup=mt.__index
        mt.__index=function(self,key)
            if self.props.ClassName=='SurfaceAppearance' and (key=='ColorMap' or key=='TexturePack') then error('Protected PBR read') end
            return lookup(self,key)
        end
        mt.__newindex=function(self,key,value)
            if self.ClassName=='MeshPart' and (key=='MeshId' or key=='InitialSize' or key=='MeshContent') then
                assert(not readOnlyMesh,'MeshPart.'..key..' is not writable')
            end
            if self.ClassName=='SurfaceAppearance' and key=='Parent' and value then
                assert(value.ClassName=='MeshPart','SurfaceAppearance can only be parented to MeshParts.')
            end
            if self.ClassName=='SurfaceAppearance' and (key=='ColorMap' or key=='TexturePack') then
                error('SurfaceAppearance.'..key..' requires PluginSecurity')
            end
            assign(self,key,value)
        end
    end
    return object
end
local oldClone=methods.Clone
function methods:Clone()
    local copy=oldClone(self)
    for _,child in ipairs(copy:GetDescendants()) do strict(child) end
    return strict(copy)
end
local newInstance=Instance.new
Instance.new=function(class,...)
    local object=strict(newInstance(class,...))
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
    total+=1;local ok,why=pcall(fn);readOnlyMesh=false
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
local meshFixture={root=1,nodes={
    {id=1,class='Model',name='Maxwell',properties={}},
    {id=2,class='MeshPart',name='maxwell',parent=1,meshSize={3000,2000,1000},properties={
        MeshId={type='string',value='original-mesh-id'},TextureID={type='string',value='original-texture-id'},
        Size={type='Vector3',value={2,1.2,1}},Transparency={type='number',value=0}}},
    {id=3,class='SurfaceAppearance',name='SurfaceAppearance',parent=2,properties={
        ColorMap={type='string',value='original-color-map'},TexturePack={type='string',value='original-processed-pack'}}}
}}
local function nativeMeshContext()
    replicated:ClearAllChildren()
    local ctx=context()
    ctx.catalog.nativeMeshes={folder='EncodedMeshes',nodes={['2']='EncodedMesh'},surfaces={['3']={meshId='2',name='EncodedSurface'}}}
    local folder=node('Folder','EncodedMeshes');folder.Parent=replicated
    local mesh=node('MeshPart','EncodedMesh');mesh.props.MeshId='original-mesh-id';mesh.props.TextureID='original-texture-id'
    mesh.props.InitialSize='opaque-original-load-metadata';mesh.Parent=folder
    local surface=node('SurfaceAppearance','EncodedSurface');surface.props.ColorMap='original-color-map'
    surface.props.TexturePack='original-processed-pack';surface.Parent=mesh
    ctx.assets=assetsFactory(ctx);return ctx,mesh,surface
end
check('PC readonly MeshId preserves original native load metadata and Maxwell PBR without invalid parenting',function()
    readOnlyMesh=true
    local ctx,template,surface=nativeMeshContext()
    local model=ctx.assets:construct(meshFixture,'weapons/Maxwell')
    local mesh=assert(model:FindFirstChild('maxwell'));local appearance=assert(mesh:FindFirstChild('SurfaceAppearance'))
    assert(mesh.ClassName=='MeshPart' and mesh.MeshId=='original-mesh-id','Original MeshPart was replaced')
    assert(mesh.InitialSize=='opaque-original-load-metadata','Original mesh initialization metadata was lost')
    assert(mesh.Size.X==2 and mesh.Size.Y==1.2 and mesh.Size.Z==1,'Authored Size was changed or guessed')
    assert(appearance.props.ColorMap=='original-color-map' and appearance.props.TexturePack=='original-processed-pack','Original protected PBR resources were lost')
    assert(#mesh:GetChildren()==1,'PBR was duplicated or a fallback mesh was invented')
    assert(surface.Parent==template and template.Name=='EncodedMesh','Native dependency was mutated')
    model:Destroy();ctx.cleanup:destroy();readOnlyMesh=false
end)
check('phone writable MeshId still uses original native initialization instead of a hacked new MeshPart',function()
    readOnlyMesh=false
    local ctx=nativeMeshContext();local model=ctx.assets:construct(meshFixture,'weapons/Maxwell')
    assert(model:FindFirstChild('maxwell').InitialSize=='opaque-original-load-metadata','Writable MeshId bypass lost original load metadata')
    model:Destroy();ctx.cleanup:destroy()
end)
check('missing native mesh fails by encoded dependency path within the deadline',function()
    readOnlyMesh=true
    local ctx=nativeMeshContext();replicated:ClearAllChildren();local started=tick()
    local ok,why=pcall(ctx.assets.construct,ctx.assets,meshFixture,'weapons/Maxwell')
    assert(not ok and tostring(why):find('EncodedMeshes',1,true) and tick()-started<=1.1,'Native mesh failure was hidden or unbounded')
    ctx.cleanup:destroy();readOnlyMesh=false
end)
check('user-created mesh and PBR import selects the original model backend without a server copy',function()
    for _,collidingIds in ipairs({false,true}) do
        local ctx=nativeMeshContext();if not collidingIds then ctx.catalog.nativeMeshes=nil end
        local data={version=1,root=meshFixture.root,nodes=meshFixture.nodes}
        ctx.catalog.packages['outfits/boba']={path='imported-json',modelPath='imported-original-model',count=#data.nodes,origin='user-created costume'}
        function ctx.json(path) assert(path=='imported-json');return data end
        local calls=0
        function ctx.assets:deserialize(entry,key)
            calls+=1;assert(entry.modelPath=='imported-original-model' and key=='outfits/boba')
            return node('Model','ImportedOriginal')
        end
        local model=ctx.assets:clone('outfits/boba')
        assert(calls==1 and model.Name=='ImportedOriginal','Imported MeshPart reused unrelated source IDs or reached unsupported JSON construction')
        model:Destroy();ctx.cleanup:destroy()
    end
end)
check('incomplete original mesh metadata stays a concrete failure instead of a silent import fallback',function()
    local ctx=nativeMeshContext();ctx.catalog.nativeMeshes=nil
    local data={version=1,root=meshFixture.root,nodes=meshFixture.nodes}
    ctx.catalog.packages['weapons/Maxwell']={path='original-json',modelPath='original-model',count=#data.nodes}
    function ctx.json(path) assert(path=='original-json');return data end
    local calls=0
    function ctx.assets:deserialize() calls+=1;error('Original dependency was silently replaced') end
    local ok,why=pcall(ctx.assets.clone,ctx.assets,'weapons/Maxwell')
    assert(not ok and tostring(why):find('missing from the catalog',1,true) and calls==0,'Original dependency error was concealed')
    ctx.cleanup:destroy()
end)
local function installOriginalMeshes(ctx,data)
    local dependency={folder='CompleteOriginalMeshes',nodes={},surfaces={}}
    local folder=node('Folder',dependency.folder);folder.Parent=replicated
    local templates={}
    for _,original in ipairs(data.nodes) do
        if original.class=='MeshPart' then
            local id=tostring(original.id);local name='OriginalMesh_'..id;dependency.nodes[id]=name
            local template=node('MeshPart',name)
            template.props.MeshId=original.properties.MeshId.value
            template.props.InitialSize='opaque-original-load-'..id;template.Parent=folder;templates[id]=template
        end
    end
    for _,original in ipairs(data.nodes) do
        if original.class=='SurfaceAppearance' then
            local id=tostring(original.id);local host=tostring(original.parent);local name='OriginalSurface_'..id
            dependency.surfaces[id]={meshId=host,name=name}
            local template=node('SurfaceAppearance',name)
            for _,key in ipairs({'ColorMap','TexturePack'}) do template.props[key]=original.properties[key].value end
            template.Parent=assert(templates[host])
        end
    end
    ctx.catalog.nativeMeshes=dependency
end
for _,key in ipairs({'costumes/LowerRig','costumes/TorsoRig','weapons/Sword','weapons/Maxwell'}) do
    check('complete original '..key..' restores every Instance and real joint endpoints',function()
        replicated:ClearAllChildren()
        local folder=node('Folder',originalNative.folder);folder.Parent=replicated
        for id,name in pairs(originalNative.nodes) do
            local union=node('UnionOperation',name);union.nativePayload='opaque-original-'..id;union.Parent=folder
        end
        local ctx=context();ctx.catalog.nativeCSG=originalNative
        local data=originals[key];installOriginalMeshes(ctx,data);readOnlyMesh=true
        ctx.assets=assetsFactory(ctx)
        local model=ctx.assets:construct(data,key)
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
            elseif object.ClassName=='MeshPart' then
                assert(object.InitialSize and object.InitialSize:find('opaque-original-load-',1,true)==1,'Native mesh initialization was not retained')
            end
        end
        if key=='costumes/TorsoRig' then
            assert(#data.nodes==86 and joints==24 and unbound==2,'Original TorsoRig hierarchy changed')
            local ref=assert(model:FindFirstChild('ref'))
            local skin=assert(ref:FindFirstChild('skinTorso'))
            local weld=assert(ref:FindFirstChild('WeldConstraint'))
            assert(weld.Part0==ref and weld.Part1==skin,'Original TorsoRig weld targets differ')
        elseif key=='costumes/LowerRig' then
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
