"""Native map import and warm-up budget; no avatar or morph files are loaded."""
import argparse
import subprocess
import tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);args=p.parse_args()
code=(ROOT/'Builder/tests/presentation_runtime.spec.luau').read_text()
code+=r'''
local written
local function writefile(path,body) written=path;assert(body=='native-map-bytes') end
local function getcustomasset(path)
    assert(path:sub(-5)=='.rbxm','Native binary model was written under an XML extension')
    return path
end
local imported=node('Model','MapRoot');imported:SetAttribute('marker',1)
local floor=node('Part','Floor');floor.Parent=imported;floor:SetAttribute('marker',2);floor:SetAttribute('worldNode',22)
local function getobjects(path) assert(path==written);return {imported} end
'''
for name in ['cleanup','assets','preload']:
    code+='\nlocal '+name+'Factory=(function()\n'+(ROOT/'client'/f'{name}.lua').read_text()+'\nend)()\n'
code+=r'''
local payload={version=1,root=1,nodes={
    {id=1,class='Model',name='MapRoot',properties={}},
    {id=2,class='Part',name='Floor',parent=1,properties={}}}}
local ctx={catalog={nativeMode='external',nativeNodeAttribute='marker',packages={
    ['world/Crossroads']={backend='model',path='map.json',modelPath='map.rbxm',modelFormat='rbxm',count=2}}},
    manifest={buildId='map-build'},config={Timeout=2},json=function() return payload end,
    http=function(path) assert(path=='map.rbxm');return 'native-map-bytes' end,report=function() end}
ctx.cleanup=cleanupFactory(ctx);ctx.assets=assetsFactory(ctx)
local copy=ctx.assets:clone('world/Crossroads')
assert(copy.Name=='MapRoot' and #copy:GetDescendants()==1)
assert(copy:GetAttribute('marker')==nil and copy:FindFirstChild('Floor'):GetAttribute('worldNode')==22,
    'Import discarded persistent world binding IDs or kept import-only markers')
copy:Destroy();ctx.cleanup:destroy()
local warming={catalog={packages={current={preload=true},unusedMap={preload=false}},animations={},hostedAnimations={}},
    config={Timeout=2},json=function() return {} end,report=function(message) error(message) end}
warming.cleanup=cleanupFactory(warming)
warming.assets={cache={},clone=function(_,key)
    assert(key=='current','Warm-up fetched an unused large map');return node('Model','Warmed')
end}
warming.animations={preload=function() error('No animation requested') end}
assert(preloadFactory(warming).ready,'Skipping unused maps prevented normal resource warm-up')
warming.cleanup:destroy()
print('Map assets: binary import, persistent IDs and on-demand map warm-up passed')
'''
with tempfile.TemporaryDirectory(dir=ROOT.parent) as directory:
    path=Path(directory)/'map-assets.luau';path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
