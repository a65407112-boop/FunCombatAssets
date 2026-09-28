#!/usr/bin/env python3
"""Import a user's own Accessory/clothing costume; never imports gameplay or animations."""
import argparse
import copy
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from types import SimpleNamespace
from lxml import etree as E
import model_io as M

ALLOWED = {'Model','Folder','Accessory','Part','MeshPart','SpecialMesh','BlockMesh',
           'CylinderMesh','Decal','Texture','Attachment','Weld','WeldConstraint',
           'Motor6D','Shirt','Pants','ShirtGraphic','SurfaceAppearance'}
ROOTS = {'Model','Accessory'}
SLOT_NAMES = {'pp': ('pp','LowerRig'), 'boba': ('boba','Boba','TorsoRig')}
SLOT_LOOKUP = {name: slot for slot,names in SLOT_NAMES.items() for name in names}


def default_config():
    return {'version':1,'byGender':{'Male':'pp','Female':'boba','Fembxy':'boba'},'packages':{}}


def refresh_manifest(repo):
    repo=Path(repo)
    manifest_path=repo/'manifest.json'
    if manifest_path.exists():
        manifest=json.loads(manifest_path.read_text())
        manifest['files']=M.repository_files(repo)
        M.dump(manifest_path,manifest)


def export_outfit(source, slot, repo, rbxmk='rbxmk'):
    source, repo = Path(source).resolve(), Path(repo).resolve()
    if slot not in SLOT_LOOKUP:
        raise ValueError('Slot must be pp or Boba (legacy boba and renamed model aliases are also accepted)')
    slot = SLOT_LOOKUP[slot]
    json_path, xml_path = Path('assets/outfits')/(slot+'.json'), Path('assets/outfits')/(slot+'.rbxmx')
    if source in {(repo/json_path).resolve(),(repo/xml_path).resolve()}:
        raise ValueError('Keep the original source in imports/outfits, separate from generated assets/outfits')
    raw = source.read_bytes()
    if source.suffix.lower() == '.rbxm':
        with tempfile.TemporaryDirectory(prefix='funcombat-outfit-') as temporary:
            temporary = Path(temporary)
            converter, decoded = temporary/'convert.lua', temporary/'model.rbxmx'
            converter.write_text("local a,b=...\nfs.write(b,fs.read(a,'rbxm'),'rbxmx')\n")
            executable = str(Path(shutil.which(str(rbxmk)) or rbxmk).resolve())
            result = subprocess.run([executable,'run','--allow-insecure-paths',str(converter),str(source),str(decoded)],capture_output=True,text=True)
            if result.returncode or not decoded.exists() or 'stack traceback:' in result.stderr:
                raise ValueError('rbxm conversion failed: '+result.stderr[-1000:])
            raw = decoded.read_bytes()
    elif source.suffix.lower() != '.rbxmx':
        raise ValueError('Export your Model as .rbxmx or .rbxm, not a place or Lua script')
    parser = E.XMLParser(resolve_entities=False, no_network=True)
    tree = E.fromstring(M.normalize_xml(raw), parser)
    roots = tree.findall('Item')
    if tree.tag != 'roblox' or len(roots) != 1 or roots[0].get('class') not in ROOTS:
        raise ValueError('Export one Model or Accessory root')
    root = roots[0]
    shared_ids={p.text for p in root.iter('SharedString')}
    shared={p.get('md5'):p for p in tree.findall('SharedStrings/SharedString')}
    missing=shared_ids-set(shared)
    if missing:
        raise ValueError('Missing SharedString definitions: '+', '.join(sorted(str(x) for x in missing)))
    if M.Source.name(root) not in SLOT_NAMES[slot]:
        raise ValueError('Expected root name '+', '.join(SLOT_NAMES[slot])+'; names are not changed automatically')
    elements = list(root.iter('Item'))
    if len(elements) > 1500:
        raise ValueError('Costume exceeds 1500 objects')
    refs = {e.get('referent') for e in elements}
    if None in refs or len(refs) != len(elements):
        raise ValueError('Missing or duplicate model reference')
    for element in elements:
        cls = element.get('class')
        if cls not in ALLOWED:
            raise ValueError(cls+' is not a costume class; gameplay and animations are separate')
        for prop in element.findall('Properties/Ref'):
            if prop.text not in refs | {'null','nil',None}:
                raise ValueError('External reference '+str(prop.text)+'; export self-contained accessories')
    wearables = 0
    for element in elements:
        cls = element.get('class')
        if cls == 'Accessory':
            wearables += 1
            handle = next((e for e in element.findall('Item') if M.Source.name(e) == 'Handle'), None)
            if handle is None or handle.get('class') not in {'Part','MeshPart'}:
                raise ValueError('Every Accessory needs a Part/MeshPart named Handle')
        elif cls in {'Shirt','Pants','ShirtGraphic'}:
            wearables += 1
        elif cls in {'Part','MeshPart'}:
            if not any(p.tag == 'Item' and p.get('class') == 'Accessory' for p in element.iterancestors()):
                raise ValueError('Put costume parts inside an Accessory with a Handle')
    if not wearables:
        raise ValueError('Costume has no accessories or clothing')
    adapter = SimpleNamespace(by=dict(enumerate(elements)),reverse={e.get('referent'):i for i,e in enumerate(elements)},name=M.Source.name)
    data = M.package(adapter,0,set())
    if data['externalReferences']:
        raise ValueError('Costume contains external references')
    config_path = repo/'config/outfits.json'
    config = json.loads(config_path.read_text()) if config_path.exists() else default_config()
    if config.get('version') != 1 or not isinstance(config.get('packages'),dict):
        raise ValueError('Unsupported config/outfits.json')
    M.dump(repo/json_path,data)
    saved = E.Element('roblox',version='4'); saved.append(copy.deepcopy(root))
    if shared_ids:
        dictionary=E.SubElement(saved,'SharedStrings')
        for key in sorted(shared_ids):dictionary.append(copy.deepcopy(shared[key]))
    E.ElementTree(saved).write(str(repo/xml_path),encoding='utf-8',xml_declaration=False)
    entry = {'path':json_path.as_posix(),'modelPath':xml_path.as_posix(),'count':len(data['nodes']),
             'sha256':M.sha(repo/json_path),'sourceSha256':M.sha(source),'origin':'user-created costume'}
    config['packages'][slot] = entry
    M.dump(config_path,config)
    refresh_manifest(repo)
    return entry


def import_directory(repo, rbxmk='rbxmk'):
    """Prepare all uploads before publishing any of them; called by GitHub Actions."""
    repo=Path(repo).resolve()
    inputs=repo/'imports/outfits'
    sources=[]
    expected={name+suffix for name in SLOT_LOOKUP for suffix in ('.rbxmx','.rbxm')}
    for source in inputs.rglob('*') if inputs.exists() else []:
        if source.suffix.lower() in {'.rbxmx','.rbxm'} and (source.parent!=inputs or source.name not in expected):
            raise ValueError('Expected pp or Boba in imports/outfits as .rbxmx/.rbxm; accepted names: '+', '.join(SLOT_LOOKUP)+': '+str(source))
    for slot in ('pp','boba'):
        choices=[inputs/(name+suffix) for name in SLOT_NAMES[slot] for suffix in ('.rbxmx','.rbxm') if (inputs/(name+suffix)).is_file()]
        if len(choices)>1:raise ValueError('Keep one source per costume slot '+slot+'; duplicate formats/names: '+', '.join(p.name for p in choices))
        if choices:sources.append((slot,choices[0]))
    with tempfile.TemporaryDirectory(prefix='funcombat-prepared-outfits-') as temporary:
        staging=Path(temporary)
        config=repo/'config/outfits.json'
        if config.exists():
            (staging/'config').mkdir()
            shutil.copy2(config,staging/'config/outfits.json')
        for slot,source in sources:export_outfit(source,slot,staging,rbxmk)
        # Invalid uploads above leave every live generated file unchanged.
        for slot,_ in sources:
            for suffix in ('.json','.rbxmx'):
                relative=Path('assets/outfits')/(slot+suffix)
                (repo/relative).parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(staging/relative,repo/relative)
        if sources:
            config.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(staging/'config/outfits.json',config)
    refresh_manifest(repo)
    return [slot for slot,_ in sources]


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',required=True,type=Path)
    ap.add_argument('--slot',required=True,choices=list(SLOT_LOOKUP))
    ap.add_argument('--repo',type=Path,default=Path(__file__).resolve().parent.parent/'GitHub')
    ap.add_argument('--rbxmk',default='rbxmk')
    args=ap.parse_args()
    entry=export_outfit(args.source,args.slot,args.repo,args.rbxmk)
    print('Imported own costume:',args.slot,entry['count'],'objects; upload assets/outfits, config/outfits.json and manifest.json')


if __name__=='__main__':main()
