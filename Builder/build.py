#!/usr/bin/env python3
"""Source-specific reproducible FunCombat exporter and server assembler.

No geometry inspection is performed. Full original map properties and embedded
data are copied by the DOM serializer. Source must never be inside output.
"""
from __future__ import annotations
import argparse,base64,copy,hashlib,json,os,re,shutil,sys,zipfile,zlib,subprocess
from pathlib import Path
from lxml import etree as E

ROOT=Path(__file__).resolve().parents[1]
if not (ROOT/'tools/outfits').exists() and (ROOT/'GitHub/tools/outfits').exists():ROOT=ROOT/'GitHub'
sys.path.insert(0,str(ROOT/'tools/outfits'))
from model_io import Source,package,animation,dump,sha,repository_files

SOURCE_SHA='a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0'
VERSION=4
SERIALIZATION_VERSION=2
ACTIONS=['Equip','Swing','Dash','GetUp','Emote','Vote','Drop','Gender','Admin','SpawnDummy','SecretDoor','PairSpeed']
EVENTS=['State','Animation','StopAnimation','Sound','Effect','Damage','Subtitle','Awaken','Voting','Weather','Admin','Remove','Notice','Error','Pair']
NETWORK=[('Folder','Folder'),('Action','RemoteEvent'),('Presentation','RemoteEvent'),('Snapshot','RemoteFunction'),('Version','IntValue'),('BuildId','StringValue')]
SCRIPT_CLASSES={'Script','LocalScript','ModuleScript'}
ORPHAN_NETWORK_CLASSES={'RemoteEvent','RemoteFunction','BindableEvent','BindableFunction'}
COSMETIC_CLASSES={'BillboardGui','ScreenGui','SurfaceGui','ParticleEmitter','Trail','Beam','Highlight','Sound'}

def safe_output(source,output):
    source,output=Path(source).resolve(),Path(output).resolve()
    if source==output or output in source.parents:raise ValueError('Output must not contain or overwrite the original source')
    if output==ROOT or output in ROOT.parents:raise ValueError('Output must not overwrite the builder repository')
    if ROOT in output.parents and output.relative_to(ROOT).parts[0]!='dist':raise ValueError('Output inside the repository must be under dist to prevent recursive copying')
    return output

def lua(value):
    if value is None:return 'nil'
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,(int,float)):return repr(value)
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False).replace('\\/','/')
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(value.items(),key=lambda x:str(x[0])))+'}'
    raise TypeError(type(value))

def write_module(path,value):path.write_text('return '+lua(value)+'\n',encoding='utf8')
def code_id(namespace,key):return hashlib.sha256((SOURCE_SHA+'|'+namespace+'|'+key).encode()).hexdigest()[:12]

def set_property(item,name,tag,value):
    props=item.find('Properties')
    if props is None:props=E.SubElement(item,'Properties')
    old=props.find('*[@name="'+name+'"]')
    if old is not None:props.remove(old)
    p=E.SubElement(props,tag,name=name);p.text=str(value)
    return p

def instance(cls,name):
    element=E.Element('Item',{'class':cls,'referent':'RBXGEN'+code_id('instance',cls+'/'+name)})
    E.SubElement(element,'Properties');set_property(element,'Name','string',name)
    return element

def xml_document(source,item):
    root=E.Element('roblox',{'version':'4'})
    E.SubElement(root,'External').text='null';E.SubElement(root,'External').text='nil'
    root.append(copy.deepcopy(item))
    shared=source.tree.find('SharedStrings')
    if shared is not None:
        used={p.text for p in root.iter('SharedString')};selected=E.SubElement(root,'SharedStrings')
        for s in shared:
            if s.get('md5') in used:selected.append(copy.deepcopy(s))
    # Roblox's older XML codec requires double-quoted declarations; omitting
    # the optional declaration avoids lxml's single-quoted prologue entirely.
    return E.tostring(root,encoding='utf-8',xml_declaration=False)

def canonical_referents(source):
    mapping={e.get('referent'):'RBXSRC%06d'%i for i,e in source.by.items()}
    for e in source.by.values():e.set('referent',mapping[e.get('referent')])
    for p in source.tree.iter('Ref'):
        if p.text in mapping:p.text=mapping[p.text]
    source.reverse={e.get('referent'):i for i,e in source.by.items()}

def copy_repository(destination):
    if destination.exists():shutil.rmtree(destination)
    shutil.copytree(ROOT,destination,ignore=shutil.ignore_patterns('.git','__pycache__','*.pyc','dist','.cache','.superpowers'))

def export(source,repo):
    catalog=json.loads((repo/'config/assets.json').read_text())
    additions={'costumes/LowerRig':7652,'costumes/TorsoRig':7710,'gui/meter':6900,
        'gui/completionLeader':7316,'gui/stats':7304,'gui/yeah':7048,'audio/Heartbeat':6910}
    for i in source.descendants(7407):
        if source.by[i].get('class')=='Sound':additions['audio/'+source.name(source.by[i])]=i
    for i in source.descendants(7522):
        if source.name(source.by[i])=='Hearts':additions['effects/Hits/Hearts']=i
    for i in range(7579,7583):additions['effects/LevelUp/UpCompletion_'+str(i)]=i
    for key,i in additions.items():
        stem=re.sub(r'[^A-Za-z0-9_]+','_',key)+'_'+code_id('asset',key)[:8]
        catalog['packages'][key]={'sourceId':i,'path':'assets/source/'+stem+'.json','modelPath':'assets/source/'+stem+'.rbxmx'}
    for key in ('meter','completionLeader','yeah'):
        if key not in catalog['gui']:catalog['gui'].append(key)
    for i in source.descendants(28286):
        if source.by[i].get('class')=='KeyframeSequence':
            key=source.paths[i].split('/Animations/',1)[1]
            if key not in catalog['animations']:
                stem=re.sub(r'[^A-Za-z0-9_]+','_',key)+'_'+code_id('animation',key)[:8]
                catalog['animations'][key]={'sourceId':i,'path':'assets/animations/'+stem+'.json'}
    for key,entry in sorted(catalog['packages'].items()):
        if key in additions:
            wanted={n['id'] for n in package(source,entry['sourceId'])['nodes']}
        else:
            old=json.loads((repo/entry['path']).read_text())
            wanted={n['id'] for n in old['nodes']}
        excluded=set(source.descendants(entry['sourceId']))-wanted
        data=package(source,entry['sourceId'],excluded=excluded)
        if {n['id'] for n in data['nodes']}!=wanted:raise ValueError('Asset export changed source membership: '+key)
        if data['externalReferences']:raise ValueError('Unresolved presentation dependency: '+key)
        dump(repo/entry['path'],data)
        item=copy.deepcopy(source.by[entry['sourceId']])
        for child in list(item.iter('Item')):
            if child is not item and source.reverse[child.get('referent')] not in wanted:
                parent=child.getparent()
                if parent is not None:parent.remove(child)
        refs={e.get('referent') for e in item.iter('Item')}
        for p in item.iter('Ref'):
            if p.text not in refs:p.text='null'
        (repo/entry['modelPath']).parent.mkdir(parents=True,exist_ok=True)
        (repo/entry['modelPath']).write_bytes(xml_document(source,item))
        entry['count']=len(data['nodes']);entry['sha256']=sha(repo/entry['path'])
        entry['backend']='model' if any(n['class']=='UnionOperation' for n in data['nodes']) else 'instances'
    timing={}
    for key,entry in sorted(catalog['animations'].items()):
        data=animation(source,entry['sourceId'])
        speed=250 if key in {'bat/gripAttacker','bat/gripVictim','bat/finishHoldAttacker','bat/finishHoldVictim'} else 350 if key.startswith(('male/','female/')) and key.endswith(('/2','/3')) else 50
        data['sourcePlaybackSpeed']=speed;dump(repo/entry['path'],data)
        import math
        duration=sum(max(1,math.ceil(f['time']/speed*60-0.00001))/60 for f in data['frames'])
        timing[key]={'duration':duration,'loop':data['loop']}
        entry['sha256']=sha(repo/entry['path']);entry['sourcePlaybackSpeed']=speed
    scripts=repo/'source/scripts';scripts.mkdir(parents=True,exist_ok=True)
    script_index=[]
    for i,e in source.by.items():
        if e.get('class') in SCRIPT_CLASSES:
            body=source.basic[i]['props'].get('Source',b'')
            path=scripts/(str(i)+'.lua');path.write_bytes(body)
            script_index.append({'sourceId':i,'class':e.get('class'),'path':source.paths[i],'export':'source/scripts/'+path.name})
    dump(repo/'source/scripts.json',script_index)
    for label,i in [('RiukTheBest',4),('Kohl_Admin',6656)]:
        path=repo/'source/external'/(label+'.rbxmx');path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(xml_document(source,source.by[i]))
    catalog['costumes']=['LowerRig','TorsoRig']
    catalog['sourceSha256']=source.sha;dump(repo/'config/assets.json',catalog)
    return catalog,timing

def strip_executables(item):
    for e in list(item.iter('Item')):
        if e is not item and e.get('class') in SCRIPT_CLASSES|ORPHAN_NETWORK_CLASSES:
            parent=e.getparent()
            if parent is not None:parent.remove(e)

def strip_rig(item):
    strip_executables(item)
    for e in list(item.iter('Item')):
        if e is not item and (e.get('class') in COSMETIC_CLASSES or e.get('class')=='ProximityPrompt'):
            parent=e.getparent()
            if parent is not None:parent.remove(e)
    return item

def children_named(item,name):return [e for e in item.findall('Item') if Source.name(e)==name]
def empty(item):
    for child in item.findall('Item'):item.remove(child)

def build_place(source,repo,output,timing):
    tree=copy.deepcopy(source.tree)
    # Do not retain proxies for 60,000 removed presentation nodes. Keeping all
    # of them alive while detaching their parents makes lxml teardown quadratic.
    kept_ids={17,6664,6875,6876,7303,78221,78368}
    by={i:e for i,e in enumerate(tree.iter('Item')) if i in kept_ids}
    # All client exports are completed before removal of their original containers.
    for i in (6876,6875,7303,78221,78368):empty(by[i])
    for i in (4,6656):
        e=next((item for item in tree.iter('Item') if item.get('referent')=='RBXSRC%06d'%i),None)
        if e is None:raise ValueError('Missing original external admin root')
        parent=e.getparent()
        if parent is not None:parent.remove(e)
    for e in list(tree.iter('Item')):
        if e.get('class') in SCRIPT_CLASSES|ORPHAN_NETWORK_CLASSES:
            parent=e.getparent()
            if parent is not None:parent.remove(e)
    # Preserve original map/CSG/Terrain and physics. No mesh or geometry probing.
    strip_rig(by[6664])
    starter=tree.find('Item[@class="StarterPlayer"]')
    starting_rig=children_named(starter,'StarterCharacter')[0]
    starting_humanoid=starting_rig.find('Item[@class="Humanoid"]')
    starting_root=children_named(starting_rig,'HumanoidRootPart')[0]
    # Our server applies the original R6 description once, after safe placement.
    # Keep the template alive even before CharacterAdded/server setup runs.
    set_property(starter,'LoadCharacterAppearance','bool','false')
    set_property(starting_humanoid,'RequiresNeck','bool','false')
    set_property(starting_humanoid,'BreakJointsOnDeath','bool','false')
    set_property(starting_root,'Anchored','bool','true')
    # Original rig decals/body colors are physics-compatible appearance; required
    # engine avatar body parts stay authoritative and are not rebuilt as duplicates.
    data=instance('Folder','FunCombatData');by[78368].append(data)
    maps=copy.deepcopy(source.by[7796]);set_property(maps,'Name','string','Maps');strip_executables(maps)
    data.append(maps)
    rig=strip_rig(copy.deepcopy(source.by[7319]));set_property(rig,'Name','string','DummyRig');data.append(rig)
    music=copy.deepcopy(source.by[source.child(2,'currentSound')]);set_property(music,'Name','string','MapMusic');data.append(music)
    carry_id=source.child(7407,'carryWeld')
    if carry_id is None:raise ValueError('Original carryWeld dependency is missing')
    weld=copy.deepcopy(source.by[carry_id]);set_property(weld,'Name','string','CarryWeld')
    for p in weld.iter('Ref'):p.text='null'
    data.append(weld)
    identifiers=json.loads((repo/'config/identifiers.json').read_text())
    prompts=instance('Folder','Prompts');data.append(prompts)
    prompt_names=[]
    for key,i in [('DefaultFun',7646),('stopPrompt',7647)]:
        original=source.by[i]
        identifiers['prompts'][key]={'sourceId':i,'name':code_id('prompt',key),
            'actionText':original.findtext('Properties/string[@name="ActionText"]',''),
            'objectText':original.findtext('Properties/string[@name="ObjectText"]',''),
            'style':0,'encodedActionText':code_id('promptAction',key),'encodedObjectText':code_id('promptObject',key)}
    identifiers['mapPrompts']={}
    map_prompt_names=[]
    for root_item in (by[17],maps):
        for p in root_item.iter('Item'):
            if p.get('class')!='ProximityPrompt':continue
            i=source.reverse[p.get('referent')];key='map/'+str(i);name=code_id('prompt',key)
            identifiers['mapPrompts'][name]={'sourceId':i,'path':source.paths[i],
                'actionText':p.findtext('Properties/string[@name="ActionText"]',''),
                'objectText':p.findtext('Properties/string[@name="ObjectText"]',''),'style':0}
            set_property(p,'Name','string',name);set_property(p,'ActionText','string',code_id('promptAction',key))
            set_property(p,'ObjectText','string',code_id('promptObject',key));set_property(p,'Style','token','1')
            map_prompt_names.append(name)
    prompt_keys=('executePrompt','carryPrompt','dropPrompt','finishHoldPrompt','DefaultFun','stopPrompt')
    for key in prompt_keys:
        entry=identifiers['prompts'][key];p=copy.deepcopy(source.by[entry['sourceId']])
        set_property(p,'Name','string',entry['name']);set_property(p,'ActionText','string',entry['encodedActionText'])
        set_property(p,'ObjectText','string',entry['encodedObjectText']);set_property(p,'Style','token','1');set_property(p,'Enabled','bool','false')
        prompts.append(p);prompt_names.append(entry['name'])
    generated={p.name:p.read_text(encoding='utf8') for p in sorted((ROOT/'Builder/templates/server').glob('*.lua'))}
    generated['MoveData.lua']=source.basic[7404]['props']['Source'].decode('utf8')
    generated['AnimationTiming.lua']='return '+lua(timing)+'\n'
    tvsource=source.basic[6588]['props']['Source'].decode()
    def string_array(name):
        block=re.search(r'local '+name+r' = \{(.*?)\}',tvsource,re.S)
        if not block:raise ValueError('Source television configuration not found')
        return re.findall(r'"([^"]+)"',block[1])
    active_source_maps=[m for m in source.tree.find('Item[@class="Workspace"]').findall('Item') if children_named(m,'IsMap')]
    if len(active_source_maps)!=1:raise ValueError('Source must define exactly one active original map')
    initial_map=Source.name(active_source_maps[0])
    if not children_named(maps,initial_map):raise ValueError('The original active map has no saved source template: '+initial_map)
    worlddata={'initialMap':initial_map,'tvSongs':string_array('songs'),'tvImages':string_array('images'),
        'music':[int(v) for v in re.findall(r'\b\d{8,}\b',source.basic[2]['props']['Source'].decode())]}
    generated['WorldData.lua']='return '+lua(worlddata)+'\n'
    seed=source.sha+'\nserialization='+str(SERIALIZATION_VERSION)+'\n'+''.join(k+v for k,v in sorted(generated.items()))
    seed+=''.join(p.relative_to(repo).as_posix()+p.read_text(encoding='utf8') for p in sorted((repo/'client').glob('*.lua')))
    seed+=(repo/'config/assets.json').read_text()+(repo/'config/outfits.json').read_text()
    seed+=lua([VERSION,ACTIONS,EVENTS,prompt_names,map_prompt_names])
    build_id=hashlib.sha256(seed.encode()).hexdigest()[:24]
    names=[code_id('network',x[0]) for x in NETWORK]
    actions={name:code_id('action',name) for name in ACTIONS}
    events={name:code_id('event',name) for name in EVENTS}
    protocol={'version':VERSION,'buildId':build_id,'folder':'ReplicatedStorage/'+names[0],
        'names':dict(zip([x[0] for x in NETWORK],names)),
        'instances':{names[i]:cls for i,(_,cls) in enumerate(NETWORK) if i>0},
        'actionIds':actions,'eventIds':events,'sourceSha256':source.sha,
        'actions':{'Equip':'allowlisted original name, or empty string','Swing':'no payload','Dash':'optional {direction:Vector3}',
            'GetUp':'one recovery input; server requires 20 accepted inputs and health >= 50%',
            'Emote':'original name/index or Stop','Vote':'allowlisted current candidate','Drop':'owned carry only',
            'Gender':'Male/Female/Fembxy for requester','Admin':'original admin allowlist; unambiguous username',
            'SpawnDummy':'optional positive integer userId; 3s cooldown, 4/player, 20/server','SecretDoor':'original Crossroads command',
            'PairSpeed':'no payload; server checks owned interaction, phase and meter thresholds'},
        'prompts':dict(zip(prompt_keys,prompt_names)),
        'authority':'Server owns damage, targets, timing, state, interactions and shared world results.',
        'obfuscation':'Identifier encoding is not authorization or protection against reverse engineering.'}
    config={'version':VERSION,'buildId':build_id,'names':names,'prompts':prompt_names,'mapPrompts':{name:True for name in map_prompt_names},
        'actions':{actions[a]:i+1 for i,a in enumerate(ACTIONS)},'actionIds':[actions[a] for a in ACTIONS],
        'events':[events[e] for e in EVENTS]}
    generated['Config.lua']='return '+lua(config)+'\n'
    dump(repo/'config/protocol.json',protocol)
    identifiers['mode']='opaque-network-and-prompts';identifiers['scope']='Network objects/actions/events and prompt names/labels; map and engine names preserved.'
    identifiers['network']=protocol['names'];identifiers.pop('reason',None);identifiers.pop('newRuntimeNames',None)
    dump(repo/'config/identifiers.json',identifiers)
    net=instance('Folder',names[0]);by[7303].append(net)
    for i,(_,cls) in enumerate(NETWORK):
        if i==0:continue
        obj=instance(cls,names[i]);net.append(obj)
        if cls=='IntValue':set_property(obj,'Value','int64',VERSION)
        if cls=='StringValue':set_property(obj,'Value','string',build_id)
    runtime=instance('Folder','FunCombatServer');by[78221].append(runtime)
    for name,body in sorted(generated.items()):
        is_main=name=='Main.server.lua';label='Main' if is_main else name.removesuffix('.lua')
        obj=instance('Script' if is_main else 'ModuleScript',label)
        set_property(obj,'Source','ProtectedString',body)
        if is_main:set_property(obj,'Disabled','bool','false')
        runtime.append(obj)
    # Remove dangling references after dependency migration (not geometry checks).
    refs={e.get('referent') for e in tree.iter('Item')}
    cleared=[]
    for p in tree.iter('Ref'):
        if p.text not in refs and p.text not in {'null','nil',None}:
            cleared.append({'property':p.get('name'),'target':p.text});p.text='null'
    # Remove unused shared-string payloads, keeping every payload still referenced.
    shared=tree.find('SharedStrings')
    if shared is not None:
        used={p.text for e in tree.iter('Item') for p in e.findall('Properties/SharedString')}
        for item in list(shared):
            if item.get('md5') not in used:shared.remove(item)
    for root_child in list(tree.findall('Item')):
        if root_child.get('class')=='Instance' and Source.name(root_child)=='FilteredSelection':tree.remove(root_child)
    target=output/'Game_Server.rbxlx'
    target.write_bytes(E.tostring(tree,encoding='utf-8',xml_declaration=False))
    server_out=output/'Builder/generated/server';server_out.mkdir(parents=True,exist_ok=True)
    for name,body in generated.items():(server_out/name).write_text(body,encoding='utf8')
    dump(output/'Build_Metadata.json',{'sourceSha256':source.sha,'protocolVersion':VERSION,'buildId':build_id,'serializationVersion':SERIALIZATION_VERSION,
        'sourceInstances':len(source.by),'serverInstances':len(list(tree.iter('Item'))),'clearedReferences':cleared,
        'geometryInspected':False,'robloxEngineTested':False,'rbxmkVersion':'0.9.1'})
    return protocol

def seal_manifest(repo,protocol):
    manifest=json.loads((repo/'manifest.json').read_text())
    manifest['protocolVersion']=VERSION;manifest['buildId']=protocol['buildId']
    manifest['serializationVersion']=SERIALIZATION_VERSION
    manifest['sourceSha256']=SOURCE_SHA;manifest['buildStatus']='assembled; offline checks only; Roblox tests required'
    manifest['scope']='Original source resources, combat, costumes and paired interactions; authoritative server adaptation.'
    manifest['project']='FunCombat_ExecutorSide_Combat'
    if 'pair' not in manifest['modules']:manifest['modules'].insert(manifest['modules'].index('main'),'pair')
    manifest['dependencies']['pair']=['assets','networking','state','gui','audio']
    manifest['dependencies']['main'].append('pair') if 'pair' not in manifest['dependencies']['main'] else None
    manifest['namesPreserved']='except encoded network and prompts'
    manifest['files']=repository_files(repo)
    dump(repo/'manifest.json',manifest)

def archive(path,base,selection=None):
    files=selection if selection is not None else [p for p in sorted(base.rglob('*')) if p.is_file()]
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted(files):
            if not p.is_file() or {'.git','__pycache__','.cache'}.intersection(p.relative_to(base).parts):continue
            info=zipfile.ZipInfo(p.relative_to(base).as_posix(),(2026,10,4,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16
            z.writestr(info,p.read_bytes())

def build(source_path,rbxmk,output):
    original=Path(source_path).resolve();output=safe_output(original,output)
    before=sha(original)
    if before!=SOURCE_SHA:raise ValueError('This builder only accepts the inspected source; checksum mismatch')
    output.mkdir(parents=True,exist_ok=True)
    source=Source(original,rbxmk,output/'.cache')
    print('Decoded original source; exporting original resources',flush=True)
    canonical_referents(source)
    repo=output/'GitHub';copy_repository(repo)
    catalog,timing=export(source,repo)
    print('Exported resources; assembling authoritative server',flush=True)
    protocol=build_place(source,repo,output,timing)
    print('Assembled XML place; encoding binary rbxl',flush=True)
    converter=output/'.cache/to_binary.lua'
    converter.write_text("local a,b=...\nfs.write(b,fs.read(a,'rbxlx'),'rbxl')\n")
    executable=str(Path(shutil.which(str(rbxmk)) or rbxmk).resolve())
    binary=output/'funcombat_server.rbxl'
    if binary.exists():binary.unlink()
    encoded=subprocess.run([executable,'run','--allow-insecure-paths',str(converter),str(output/'Game_Server.rbxlx'),str(binary)],check=True,capture_output=True,timeout=120)
    if not binary.exists() or not binary.read_bytes().startswith(b'<roblox!'):
        raise RuntimeError('rbxmk did not write a binary place: '+encoded.stderr.decode(errors='replace'))
    metadata=json.loads((output/'Build_Metadata.json').read_text());metadata['binarySha256']=sha(binary);dump(output/'Build_Metadata.json',metadata)
    server_binary=repo/'server/funcombat_server.rbxl';server_binary.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(binary,server_binary)
    print('Encoded binary place; sealing manifest and checking structure',flush=True)
    seal_manifest(repo,protocol)
    shutil.copy2(repo/'loader.lua',output/'loader.lua')
    shutil.copytree(ROOT/'Builder',output/'Builder',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    for name in ('Validation_Report.md','Changes_For_Review.md'):
        if (ROOT/name).exists():shutil.copy2(ROOT/name,output/name)
    shutil.copy2(repo/'docs/installation.md',output/'Installation_RU.md')
    archived_source=output/'Source/FunCombat_Original.rbxl';archived_source.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(original,archived_source)
    if sha(original)!=before:raise RuntimeError('Original source changed unexpectedly')
    from validate import validate
    findings=validate(output)
    dump(output/'Static_Checks.json',findings)
    archive(output/'Game_GitHub.zip',repo)
    package_files=[p for p in output.rglob('*') if p.is_file() and p.name not in {'Game_GitHub.zip','Game_ExecutorSide.zip'} and '.cache' not in p.relative_to(output).parts]
    archive(output/'Game_ExecutorSide.zip',output,package_files)
    print('Built archives; original source checksum unchanged',flush=True)
    return {'output':str(output),'sourceUnchanged':True,'buildId':protocol['buildId'],'packages':len(catalog['packages']),'animations':len(catalog['animations']),'checks':findings}

if __name__=='__main__':
    args=argparse.ArgumentParser(description=__doc__)
    args.add_argument('--source',required=True);args.add_argument('--rbxmk',default='rbxmk');args.add_argument('--output',default=str(ROOT/'dist'))
    opt=args.parse_args()
    print(json.dumps(build(opt.source,opt.rbxmk,opt.output),ensure_ascii=False,indent=2))
