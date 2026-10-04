"""Offline structural checks. This module never inspects model geometry."""
from pathlib import Path
import hashlib,json,re,zlib
from lxml import etree as E

def require(condition,message):
    if not condition:raise ValueError(message)

def references(tree,label):
    items=list(tree.iter('Item'));ids=[e.get('referent') for e in items]
    require(len(ids)==len(set(ids)),label+': duplicate referents')
    known=set(ids)
    for p in tree.iter('Ref'):require(p.text in known or p.text in {'null','nil',None},label+': unresolved reference '+str(p.text))
    shared={e.get('md5') for e in tree.findall('SharedStrings/SharedString')}
    for p in tree.iter('Item'):
        for s in p.findall('Properties/SharedString'):require(s.text in shared or not s.text,label+': missing shared data')
    return len(items)

def validate(output):
    output=Path(output);repo=output/'GitHub'
    protocol=json.loads((repo/'config/protocol.json').read_text())
    catalog=json.loads((repo/'config/assets.json').read_text())
    manifest=json.loads((repo/'manifest.json').read_text())
    identifiers=json.loads((repo/'config/identifiers.json').read_text())
    require(protocol['version']==manifest['protocolVersion']==4,'Protocol version mismatch')
    require(protocol['buildId']==manifest['buildId'],'Build ID mismatch')
    require(protocol['sourceSha256']==catalog['sourceSha256']==manifest['sourceSha256'],'Source checksum mismatch')
    for path,entry in manifest['files'].items():
        f=repo/path;require(f.is_file(),'Missing repository file: '+path);raw=f.read_bytes()
        require(len(raw)==entry['bytes'] and hashlib.sha256(raw).hexdigest()==entry['sha256'] and zlib.adler32(raw)&0xffffffff==entry['adler32'],'File integrity mismatch: '+path)
    visiting,visited=set(),set()
    def walk(name):
        require(name in manifest['modules'],'Undeclared dependency: '+name)
        require(name not in visiting,'Circular dependency: '+name)
        if name in visited:return
        visiting.add(name)
        for dependency in manifest['dependencies'].get(name,[]):walk(dependency)
        visiting.remove(name);visited.add(name)
    for name in manifest['modules']:walk(name)
    xml=E.parse(str(output/'Game_Server.rbxlx')).getroot()
    count=references(xml,'Server place')
    items=list(xml.iter('Item'));byname={}
    for e in items:byname.setdefault(e.findtext('Properties/string[@name="Name"]'),[]).append(e)
    for key,name in protocol['names'].items():
        require(len(byname.get(name,[]))==1,'Network identifier is missing/duplicate: '+key)
        e=byname[name][0]
        expected='Folder' if key=='Folder' else protocol['instances'][name]
        require(e.get('class')==expected,'Network class mismatch: '+key)
    require(byname[protocol['names']['Version']][0].findtext('Properties/int[@name="Value"]')=='4','Wrong encoded version value')
    require(byname[protocol['names']['BuildId']][0].findtext('Properties/string[@name="Value"]')==manifest['buildId'],'Wrong encoded build value')
    remotes=[e for e in items if e.get('class') in {'RemoteEvent','RemoteFunction'}]
    require(len(remotes)==3,'Unexpected server network instances')
    require(not any(e.get('class')=='LocalScript' for e in items),'Server contains client scripts')
    prompt_ids={e['name'] for e in identifiers['prompts'].values()}|set(identifiers['mapPrompts'])
    prompts=[e for e in items if e.get('class')=='ProximityPrompt']
    for p in prompts:
        require(p.findtext('Properties/string[@name="Name"]') in prompt_ids,'Unencoded prompt')
        require(p.findtext('Properties/token[@name="Style"]')=='1','Server prompt must hide readable labels')
        require(float(p.findtext('Properties/float[@name="HoldDuration"]','-1'))>=0,'Missing native hold duration')
    require(len(protocol['prompts'])==6,'Original character prompts missing')
    for name in protocol['prompts'].values():require(len(byname.get(name,[]))==1,'Missing native prompt template')
    nodes=0;csg=0;asset_refs=set()
    banned={'Script','LocalScript','ModuleScript','RemoteEvent','RemoteFunction','BindableEvent','BindableFunction'}
    for key,entry in catalog['packages'].items():
        package=json.loads((repo/entry['path']).read_text());ids={n['id'] for n in package['nodes']}
        require(len(ids)==len(package['nodes'])==entry['count'],'Node membership/count mismatch: '+key)
        require(package['root'] in ids and not package['externalReferences'],'Unresolved package: '+key)
        for n in package['nodes']:
            require(n['class'] not in banned,'Executable presentation asset: '+key)
            require(n['parent'] is None or n['parent'] in ids,'Missing asset parent: '+key)
            for name,p in n['properties'].items():
                if p['type']=='Ref':require(p['value'] is None or p['value'] in ids,'Missing asset reference: '+key+'/'+name)
                if name in {'MeshId','TextureId','TextureID','SoundId','AnimationId','Image','Texture'} and p['value']:asset_refs.add(str(p['value']))
            if n['class']=='UnionOperation':csg+=1;require(entry['backend']=='model','Embedded CSG lacks deserializer: '+key)
        model=E.parse(str(repo/entry['modelPath'])).getroot()
        require(references(model,key)==entry['count'],'Model/JSON membership mismatch: '+key)
        nodes+=entry['count']
    require(len(catalog['animations'])==47,'Not all original KeyframeSequences exported')
    keyframes=poses=0
    for key,entry in catalog['animations'].items():
        data=json.loads((repo/entry['path']).read_text())
        require(data['sourceId']==entry['sourceId'] and data['frames'],'Animation dependency missing: '+key)
        require(data['sourcePlaybackSpeed']==entry['sourcePlaybackSpeed'],'Animation speed metadata mismatch')
        keyframes+=len(data['frames']);poses+=sum(len(f['poses']) for f in data['frames'])
    require(set(catalog['weapons'])=={'Bat','Sword',':3','BoyKisser','Maxwell','Orange Cat'},'Original weapons missing')
    for name in ['LowerRig','TorsoRig']:require('costumes/'+name in catalog['packages'],'Original costume missing')
    raw=(output/'funcombat_server.rbxl').read_bytes()
    require(raw.startswith(b'<roblox!'),'Binary server place was not encoded as rbxl')
    return {'passed':True,'checks':['input checksum','manifest SHA256/Adler32/bytes','dependency DAG',
        'XML referents/shared data','encoded protocol/build identity','network instance counts','native prompt templates',
        'asset hierarchy and internal refs','original costume CSG deserialization route','all 47 source animations','binary rbxl header'],
        'serverInstances':count,'prompts':len(prompts),'packages':len(catalog['packages']),'packageNodes':nodes,
        'embeddedCostumeCSG':csg,'animations':47,'keyframes':keyframes,'poses':poses,'hostedReferenceCount':len(asset_refs),
        'geometryInspected':False,'robloxEngineTested':False,'legacyClientTested':False,
        'hostedAssetPermissionsTested':False,'executorModelBackendTested':False}
