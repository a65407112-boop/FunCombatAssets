"""Finalize the source-specific export as a single-saved-rig protocol-5 project.

Only hierarchy, serialized references and code bindings are inspected. Map
geometry and opaque native resource payloads are not interpreted.
"""
from pathlib import Path
import copy, hashlib, json, re, shutil, subprocess, base64, struct
from lxml import etree as E
import build as base
from luau_pack import pack, restore, tokens, normalize_tokens, string_bytes, quote_bytes
from model_io import Source, package, dump, sha, repository_files

VERSION=5
ENGINE={'StarterCharacter','Humanoid','HumanoidRootPart','Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg',
        'RootJoint','Neck','Left Shoulder','Right Shoulder','Left Hip','Right Hip','Animate','face','FaceControls','Handle','leaderstats',
        'Settings','Custom Commands','Custom_Commands','mood','Animation1','Weight','R15Anim'}
DATA_DOTS={'Maps','Prompts','CarryWeld','MapMusic','WorldSettings'}
STATS={'Kills','Killstreak','Completions'}

def find(parent,name):
    matches=[x for x in parent.findall('Item') if Source.name(x)==name]
    if len(matches)!=1:raise ValueError('Expected one '+name+', found '+str(len(matches)))
    return matches[0]

def replace_once(text,old,new):
    if text.count(old)!=1:raise ValueError('Source adaptation anchor differs: '+old[:100])
    return text.replace(old,new,1)

def quoted(text):return quote_bytes(text.encode('utf8'))

def rewrite_bindings(code,names,attributes,dots=(),client=False):
    if client:
        # External client source stays readable and retains third-party notices.
        # Only server-owned attribute bindings change; no client minifier needed.
        pattern=r'((?:GetAttribute|SetAttribute|GetAttributeChangedSignal)\(\s*)("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')'
        def attribute(match):
            key=string_bytes(match[2]).decode('utf8')
            return match[1]+(quoted(attributes[key]) if key in attributes else match[2])
        return re.sub(pattern,attribute,code)
    parts=normalize_tokens(tokens(code));out=[];calls=[];depth=0
    child_calls={'FindFirstChild','WaitForChild'}
    attr_calls={'GetAttribute','SetAttribute','GetAttributeChangedSignal'}
    for i,(kind,value) in enumerate(parts):
        if value=='(':
            depth+=1
            method=parts[i-1][1] if i else ''
            if method in child_calls|attr_calls:calls.append((depth,method))
        if kind=='string':
            text=string_bytes(value).decode('utf8');replacement=None
            active=calls[-1][1] if calls else None
            if active in attr_calls:replacement=attributes.get(text)
            elif active in child_calls and not client:replacement=names.get(text)
            if not client and i>=3 and parts[i-1][1] in {'=','==','~=','<','>'} and parts[i-2][1]=='Name' and parts[i-3][1]=='.':
                replacement=names.get(text,replacement)
            if not client and i>=2 and parts[i-1][1]=='=' and parts[i-2][1]=='BRIDGE_NAME':replacement=names.get(text)
            if replacement:value=quoted(replacement)
        if not client and i and parts[i-1][1]=='.' and value in dots:
            out.pop();out.extend(['[',quoted(names[value]),']']);continue
        out.append(value)
        if value==')':
            if calls and calls[-1][0]==depth:calls.pop()
            depth-=1
    return ' '.join(out)

def rig_data(source,root):
    excluded=[]
    for i in source.descendants(root):
        if source.by[i].get('class') in base.COSMETIC_CLASSES|{'ProximityPrompt'}:excluded.append(i)
    data=package(source,root,excluded=excluded)
    if data['externalReferences']:raise ValueError('Original rig has an external reference')
    if sum(n['class']=='Motor6D' for n in data['nodes'])!=6:raise ValueError('Original rig lost its six R6 joints')
    return data

def semantic(code):
    return [(kind,string_bytes(value) if kind=='string' else value) for kind,value in normalize_tokens(tokens(code))]

def validate_compact(output,bindings,readable):
    repo=output/'GitHub';tree=E.parse(str(output/'Game_Server.rbxlx')).getroot()
    from validate import references, binary_property_types
    count=references(tree,'Compact server')
    def named(parent,label):return find(parent,bindings['names'].get(label,label))
    workspace=tree.find('Item[@class="Workspace"]');storage=tree.find('Item[@class="ServerStorage"]')
    data=named(storage,'FunCombatData');maps=named(data,'Maps')
    environment={item.get('referent') for item in workspace.findall('Item')}
    saved_rigs=[]
    for item in tree.iter('Item'):
        if item.get('class')!='Model':continue
        ancestors=list(item.iterancestors('Item'))
        if item in maps.findall('Item') or maps in ancestors:continue
        if any(a.get('referent') in environment for a in [item]+ancestors):continue
        saved_rigs.append(item)
    if len(saved_rigs)!=1 or Source.name(saved_rigs[0])!='StarterCharacter':raise ValueError('Compact place does not contain exactly one non-environment Model')
    starter=saved_rigs[0];parts={Source.name(i):i for i in starter.findall('Item')}
    if any(name not in parts for name in ('HumanoidRootPart','Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg')):raise ValueError('Original starter body names were changed')
    motors=[i for i in starter.iter('Item') if i.get('class')=='Motor6D']
    if len(motors)!=6:raise ValueError('Original starter joints missing')
    ids={i.get('referent') for i in starter.iter('Item')}
    for motor in motors:
        for field in ('Part0','Part1'):
            if motor.findtext('Properties/Ref[@name="'+field+'"]') not in ids:raise ValueError('Starter joint points outside the character')
    active=named(workspace,'Crossroads')
    spawns=named(active,'Spawns').findall('Item')
    enabled=[x for x in spawns if x.get('class')=='SpawnLocation' and x.findtext('Properties/bool[@name="Enabled"]','true')=='true']
    if not enabled:raise ValueError('Initial original map has no enabled spawns')
    if any(Source.name(x)==bindings['mapNames']['Crossroads'] for x in maps.findall('Item')):raise ValueError('Redundant saved initial map template remains')
    rs=tree.find('Item[@class="ReplicatedStorage"]')
    if any(x.get('class') in {'MeshPart','UnionOperation','SurfaceAppearance','Model','Tool','Animation','Sound'} for x in rs.iter('Item')):raise ValueError('Replicated client presentation remained in compact server')
    catalog=json.loads((repo/'config/assets.json').read_text());protocol=json.loads((repo/'config/protocol.json').read_text());manifest=json.loads((repo/'manifest.json').read_text())
    if protocol['version']!=5 or manifest['protocolVersion']!=5 or protocol['buildId']!=manifest['buildId']:raise ValueError('Compact protocol/build mismatch')
    if len(catalog['packages'])!=129 or len(catalog['animations'])!=47:raise ValueError('Original presentation membership changed')
    native=0
    for key,entry in catalog['packages'].items():
        data=json.loads((repo/entry['path']).read_text())
        if any(n['class'] in {'MeshPart','UnionOperation','SurfaceAppearance'} for n in data['nodes']):
            native+=1
            if entry['backend']!='model' or not (repo/entry['modelPath']).is_file():raise ValueError('Original native package has no external import: '+key)
        if data['externalReferences']:raise ValueError('Unresolved external package: '+key)
    packed=0
    runtime=named(tree.find('Item[@class="ServerScriptService"]'),'FunCombatServer')
    for label,code in readable.items():
        item=named(runtime,label);actual=item.findtext('Properties/*[@name="Source"]','')
        if semantic(restore(actual))!=semantic(code):raise ValueError('Packed source changed semantics: '+label)
        packed+=1
    for item in tree.iter('Item'):
        if item.get('class')=='ProximityPrompt':
            if not re.fullmatch('[0-9a-f]{12}',Source.name(item)):raise ValueError('Readable prompt name remains')
            for field in ('ActionText','ObjectText'):
                if not re.fullmatch('[0-9a-f]{12}',item.findtext('Properties/string[@name="'+field+'"]','')):raise ValueError('Readable prompt label remains')
    for path,entry in manifest['files'].items():
        if sha(repo/path)!=entry['sha256'] or (repo/path).stat().st_size!=entry['bytes']:raise ValueError('Compact manifest mismatch '+path)
    return {'passed':True,'protocolVersion':5,'buildId':protocol['buildId'],'serverInstances':count,'nonEnvironmentModels':1,
        'savedCharacterModels':['StarterCharacter'],'runtimeOriginalRigs':2,'initialMapSavedOnce':True,'enabledInitialSpawns':len(enabled),'r6Motors':6,
        'replicatedPresentationConstructors':0,'externalNativeModelPackages':native,'packages':129,'animations':47,'packedRuntimeSources':packed,
        'promptCount':sum(x.get('class')=='ProximityPrompt' for x in tree.iter('Item')),
        'binaryPropertyTypes':binary_property_types(output/'Source/FunCombat_Original.rbxl',output/'funcombat_server.rbxl'),
        'geometryInspected':False,'robloxEngineTested':False,'executorModelBackendTested':False,'legacyClientTested':False,'hostedAssetPermissionsTested':False}

def build(source_path,rbxmk,output):
    result=base.build(source_path,rbxmk,output)
    output=Path(result['output']);repo=output/'GitHub';source=Source(source_path,rbxmk,output/'.cache')
    tree=E.parse(str(output/'Game_Server.rbxlx')).getroot()
    ws=tree.find('Item[@class="Workspace"]');ss=tree.find('Item[@class="ServerStorage"]');rs=tree.find('Item[@class="ReplicatedStorage"]');scripts=tree.find('Item[@class="ServerScriptService"]')
    data=find(ss,'FunCombatData');maps=find(data,'Maps');runtime=find(scripts,'FunCombatServer')
    initial=find(ws,'DUMMY');dummy=find(data,'DummyRig')
    ws.remove(initial);data.remove(dummy);maps.remove(find(maps,'Crossroads'))
    catalog=json.loads((repo/'config/assets.json').read_text())
    for dependency in ('nativeCSG','nativeMeshes'):
        folder=find(rs,catalog[dependency]['folder']);rs.remove(folder);catalog[dependency]['storage']='external-models'
    catalog['nativeMode']='external'
    catalog['nativeNodeAttribute']=base.code_id('native-import-marker','source-node')
    for entry in catalog['packages'].values():
        exported=json.loads((repo/entry['path']).read_text())
        entry['backend']='model' if any(n['class'] in {'MeshPart','UnionOperation','SurfaceAppearance'} for n in exported['nodes']) else 'instances'
        if entry['backend']=='model':
            model=E.parse(str(repo/entry['modelPath'])).getroot();nodes={n['id']:n for n in exported['nodes']}
            for item in model.iter('Item'):
                node=nodes[int(item.get('referent').removeprefix('RBXSRC'))]
                attrs=dict(node['attributes'])
                if catalog['nativeNodeAttribute'] in attrs:raise ValueError('Source attribute collides with native import marker')
                attrs[catalog['nativeNodeAttribute']]=node['id']
                def string(value):
                    encoded=value.encode('utf8');return struct.pack('<I',len(encoded))+encoded
                encoded=bytearray(struct.pack('<I',len(attrs)))
                for name,value in sorted(attrs.items()):
                    encoded+=string(name)
                    if isinstance(value,bool):encoded+=b'\x03'+bytes([value])
                    elif isinstance(value,(int,float)):encoded+=b'\x06'+struct.pack('<d',value)
                    elif isinstance(value,str):encoded+=b'\x02'+string(value)
                    else:raise ValueError('Unsupported source attribute type in native import')
                base.set_property(item,'AttributesSerialize','BinaryString',base64.b64encode(encoded).decode())
            (repo/entry['modelPath']).write_bytes(E.tostring(model,encoding='utf8',xml_declaration=False))
    dump(repo/'config/assets.json',catalog)
    readable={Source.name(x):x.findtext('Properties/*[@name="Source"]','') for x in runtime.findall('Item')}
    world=readable['World']
    world='local RigFactory=require(script.Parent.RigFactory)\nlocal RigData=require(script.Parent.RigData)\n'+world
    world=replace_once(world,'return self.templates.DummyRig:Clone()','return RigFactory.create(RigData.spawn)')
    world=replace_once(world,'self.activeMap=current\n                    return current','self.activeMap=current\n                    local maps=self.templates:FindFirstChild("Maps")\n                    if maps and not maps:FindFirstChild(name) then\n                        local backup=assert(current:Clone(),"Original initial map backup could not be cloned")\n                        backup.Parent=maps\n                    end\n                    return current')
    readable['World']=world
    readable['Main']='local RigFactory=require(script.Parent.RigFactory)\nlocal RigData=require(script.Parent.RigData)\nlocal originalDummy=RigFactory.create(RigData.initial)\noriginalDummy.Parent=workspace\n'+readable['Main']
    combat='local Wire=require(script.Parent.WireCodec)\nlocal Bindings=require(script.Parent.Bindings)\n'+readable['CombatServer']
    combat=replace_once(combat,'if player then self.event:FireClient(player,id,data) else self.event:FireAllClients(id,data) end','local encoded=Wire.transform(data,self.protocol.config.presentationEncode)\n    if player then self.event:FireClient(player,id,encoded) else self.event:FireAllClients(id,encoded) end')
    combat=replace_once(combat,'function(player,id,payload) self:request(player,id,payload) end','function(player,id,payload)\n        local ok,decoded=pcall(Wire.decodeAction,payload,self.protocol.config.presentationDecode)\n        if ok then self:request(player,id,decoded) end\n    end')
    combat=replace_once(combat,'return self:getSnapshot(player) end','return Wire.transform(self:getSnapshot(player),self.protocol.config.presentationEncode) end')
    combat=replace_once(combat,'r.character:SetAttribute(key,r[key]==true)','r.character:SetAttribute(Bindings.attributes[key] or key,r[key]==true)')
    readable['CombatServer']=combat
    rigs={'initial':rig_data(source,6664),'spawn':rig_data(source,7319)}
    labels={Source.name(x) for x in tree.iter('Item')}
    # Service/container names and native avatar helpers belong to Roblox.
    ENGINE.update(Source.name(x) for x in tree.findall('Item'))
    labels.update(readable);labels.update({'RigData','Bindings','DUMMY','Rig','FunCombatDummy'})
    for item in tree.iter('Item'):
        if item.get('class') in {'Attachment','Motor6D','Humanoid','FaceControls','Animator','BodyColors','Terrain','Camera','StarterPlayerScripts','StarterCharacterScripts'}:ENGINE.add(Source.name(item))
    module_labels=set(readable)|{'RigData','Bindings'}
    names={name:base.code_id('compact-name',name) for name in sorted(labels) if name not in ENGINE and not re.fullmatch('[0-9a-f]{12}',name)}
    attributes=set()
    sources='\n'.join(readable.values())
    for match in re.finditer(r'(?:GetAttribute|SetAttribute|GetAttributeChangedSignal)\(\s*("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')',sources):attributes.add(string_bytes(match[1]).decode())
    attributes.update({'downed','ragdolled','awakened','wallBounce'})
    attrmap={name:base.code_id('compact-attribute',name) for name in sorted(attributes)}
    mapnames={name:names[name] for name in ('Crossroads','OriginalMap')}
    stats={name:base.code_id('compact-stat',name) for name in sorted(STATS)}
    names.update(stats)
    for rig in rigs.values():
        for node in rig['nodes']:
            node['name']=names.get(node['name'],node['name']);node['attributes']={attrmap.get(k,k):v for k,v in node['attributes'].items()}
    readable['RigData']='return '+base.lua(rigs)+'\n'
    bindings={'names':names,'attributes':attrmap,'mapNames':mapnames,'stats':stats,'serverModules':{label:names.get(label,label) for label in sorted(module_labels)},
        'exceptions':sorted(ENGINE),'mode':'opaque saved bindings; public reversible mapping'}
    readable['Bindings']='return '+base.lua(bindings)+'\n'
    # Known static stat arrays create values whose later references use the same aliases.
    readable['CombatServer']=readable['CombatServer'].replace('{"Kills","Killstreak","Completions"}',base.lua([stats[x] for x in ('Kills','Killstreak','Completions')]))
    readable['WorldData']=replace_once(readable['WorldData'],'["initialMap"]="Crossroads"','["initialMap"]='+quoted(mapnames['Crossroads']))
    for label in list(readable):
        if label not in {'Config','Bindings','RigData'}:readable[label]=rewrite_bindings(readable[label],names,attrmap,module_labels|DATA_DOTS|STATS)
    original_protocol=json.loads((repo/'config/protocol.json').read_text())
    presentation={key:base.code_id('presentation',key) for key in sorted(set(catalog['packages'])|set(catalog['animations']))}
    wireencode=dict(presentation);wireencode.update(mapnames)
    config={'version':VERSION,'buildId':'COMPACT_BUILD_PENDING','ownerUserId':base.read_admin_settings(repo)['ownerUserId'],
        'names':[original_protocol['names'][key] for key,_ in base.NETWORK],
        'prompts':[original_protocol['prompts'][key] for key in ('executePrompt','carryPrompt','dropPrompt','finishHoldPrompt','DefaultFun','stopPrompt')],
        'mapPrompts':{name:True for name in json.loads((repo/'config/identifiers.json').read_text())['mapPrompts']},
        'actions':{original_protocol['actionIds'][key]:i+1 for i,key in enumerate(base.ACTIONS)},'actionIds':[original_protocol['actionIds'][key] for key in base.ACTIONS],
        'events':[original_protocol['eventIds'][key] for key in base.EVENTS],
        'presentationEncode':wireencode,'presentationDecode':{v:k for k,v in presentation.items()}}
    readable['Config']='return '+base.lua(config)+'\n'
    for path in (repo/'client').glob('*.lua'):
        # Only attribute calls change in the client; external presentation names stay original.
        path.write_text(rewrite_bindings(path.read_text(),names,attrmap,client=True))
    loader=(repo/'loader.lua').read_text().replace('ctx.manifest.protocolVersion == 4','ctx.manifest.protocolVersion == 5').replace('ctx.protocol.version==4','ctx.protocol.version==5')
    (repo/'loader.lua').write_text(loader)
    diagnostic=(repo/'diagnose.lua').read_text()
    diagnostic=re.sub(r'local attributeAliases=\{[^\n]*\}\n(?=local function attributes\(object\))','',diagnostic,count=1)
    reverse={v:k for k,v in attrmap.items()}
    diagnostic=diagnostic.replace('local function attributes(object)','local attributeAliases='+base.lua(reverse)+'\nlocal function attributes(object)',1)
    diagnostic=diagnostic.replace('if type(key)=="string" and key:sub(1,9)=="FunCombat" then','if attributeAliases[key] or (type(key)=="string" and key:sub(1,9)=="FunCombat") then',1)
    diagnostic=diagnostic.replace('copy[key]=value(item)','copy[attributeAliases[key] or key]=value(item)',1)
    object_aliases={key:names[key] for key in ('Configuration','AllowDummys')}
    diagnostic=re.sub(r'local objectAliases=\{[^\n]*\}\n(?=local function find\(object,name,class\))','',diagnostic,count=1)
    diagnostic=diagnostic.replace('local function find(object,name,class)','local objectAliases='+base.lua(object_aliases)+'\nlocal function find(object,name,class)',1)
    diagnostic=diagnostic.replace('local function find(object,name,class)\n','local function find(object,name,class)\n    if not class then name=objectAliases[name] or name end\n',1) if 'name=objectAliases[name]' not in diagnostic else diagnostic
    (repo/'diagnose.lua').write_text(diagnostic)
    dummy_diag=repo/'diagnose_dummy.lua'
    if dummy_diag.is_file():
        body=dummy_diag.read_text()
        body=re.sub(r'local objectAliases=\{[^\n]*\}\nlocal attributeAliases=\{[^\n]*\}\n(?=local function find\(parent,name,class\))','',body,count=1)
        body=body.replace('local function find(parent,name,class)','local objectAliases='+base.lua(object_aliases)+'\nlocal attributeAliases='+base.lua(attrmap)+'\nlocal function find(parent,name,class)',1)
        if 'name=objectAliases[name]' not in body:body=body.replace('local function find(parent,name,class)\n','local function find(parent,name,class)\n    if not class then name=objectAliases[name] or name end\n',1)
        body=body.replace('player:GetAttribute(key)','player:GetAttribute(attributeAliases[key] or key)')
        dummy_diag.write_text(body)
    seed='protocol5\n'+source.sha+'\n'+''.join(k+v for k,v in sorted(readable.items()))+json.dumps(catalog,sort_keys=True)+loader
    seed+=''.join(p.name+p.read_text() for p in sorted((repo/'client').glob('*.lua')))
    buildid=hashlib.sha256(seed.encode()).hexdigest()[:24];config['buildId']=buildid;readable['Config']='return '+base.lua(config)+'\n'
    protocol=copy.deepcopy(original_protocol);protocol.update({'version':5,'buildId':buildid,'presentationIds':presentation,'layout':'single saved original character outside map/environment; external native models'})
    dump(repo/'config/protocol.json',protocol)
    identifiers=json.loads((repo/'config/identifiers.json').read_text());identifiers.update(bindings);identifiers['scope']='Saved object/module/stat bindings, game attributes, network, prompts and presentation tokens; required engine/upstream names preserved.'
    dump(repo/'config/identifiers.json',identifiers)
    # Pack every saved server script, and encode saved object names after bindings are fixed.
    for label,code in readable.items():
        existing=[x for x in runtime.findall('Item') if Source.name(x)==label]
        obj=existing[0] if existing else base.instance('ModuleScript',label)
        if not existing:runtime.append(obj)
        base.set_property(obj,'Source','ProtectedString',pack(code))
    for item in tree.iter('Item'):
        name=Source.name(item)
        if name in names:base.set_property(item,'Name','string',names[name])
        if item.getparent() is not runtime:
            prop=item.find('Properties/*[@name="Source"]')
            if prop is not None:
                raw=prop.text or '';converted=rewrite_bindings(raw,names,attrmap,module_labels|DATA_DOTS|STATS)
                prop.text=pack(converted)
    base.set_property(find(rs,original_protocol['names']['Folder']).find('Item[@class="IntValue"]'),'Value','int64',5)
    net=find(rs,original_protocol['names']['Folder']);base.set_property(find(net,original_protocol['names']['BuildId']),'Value','string',buildid)
    known={x.get('referent') for x in tree.iter('Item')}
    for prop in tree.iter('Ref'):
        if prop.text not in known and prop.text not in {'null','nil',None}:prop.text='null'
    shared=tree.find('SharedStrings')
    if shared is not None:
        used={x.text for x in tree.iter('SharedString')}
        for item in list(shared):
            if item.get('md5') not in used:shared.remove(item)
    (output/'Game_Server.rbxlx').write_bytes(E.tostring(tree,encoding='utf8',xml_declaration=False))
    generated=output/'Builder/generated/server'
    for label,code in readable.items():
        filename='Main.server.lua' if label=='Main' else label+'.lua';(generated/filename).write_text(code)
    executable=str(Path(shutil.which(str(rbxmk)) or rbxmk).resolve())
    subprocess.run([executable,'run','--allow-insecure-paths',str(output/'.cache/to_binary.lua'),str(output/'Game_Server.rbxlx'),str(output/'funcombat_server.rbxl')],check=True,capture_output=True,timeout=120)
    shutil.copy2(output/'funcombat_server.rbxl',repo/'server/funcombat_server.rbxl')
    manifest=json.loads((repo/'manifest.json').read_text());manifest['protocolVersion']=5;manifest['buildId']=buildid;manifest['serializationVersion']=3
    manifest['namesPreserved']='required engine/upstream names only; public bindings in config/identifiers.json'
    for module in ('wire','labels'):
        if module not in manifest['modules']:manifest['modules'].insert(manifest['modules'].index('networking') if module=='wire' else manifest['modules'].index('main'),module)
    manifest['dependencies']['wire']=[];manifest['dependencies']['labels']=['cleanup','networking']
    if 'wire' not in manifest['dependencies']['networking']:manifest['dependencies']['networking'].append('wire')
    if 'labels' not in manifest['dependencies']['main']:manifest['dependencies']['main'].append('labels')
    manifest['files']=repository_files(repo);dump(repo/'manifest.json',manifest)
    for name in ('loader.lua','diagnose.lua'):shutil.copy2(repo/name,output/name)
    metadata=json.loads((output/'Build_Metadata.json').read_text());metadata.update({'protocolVersion':5,'buildId':buildid,'serializationVersion':3,'serverInstances':len(list(tree.iter('Item'))),'binarySha256':sha(output/'funcombat_server.rbxl'),'nonEnvironmentModels':1,'initialMapSavedOnce':True,'replicatedPresentationConstructors':0})
    dump(output/'Build_Metadata.json',metadata)
    findings=validate_compact(output,bindings,readable);dump(output/'Static_Checks.json',findings)
    base.archive(output/'Game_GitHub.zip',repo)
    files=[p for p in output.rglob('*') if p.is_file() and p.name not in {'Game_GitHub.zip','Game_ExecutorSide.zip'} and '.cache' not in p.relative_to(output).parts]
    base.archive(output/'Game_ExecutorSide.zip',output,files)
    if sha(source_path)!=base.SOURCE_SHA:raise ValueError('Source changed during compact finalization')
    print('Compact build complete: one saved rig; no replicated presentation constructors; protocol '+str(VERSION),flush=True)
    return {'output':str(output),'sourceUnchanged':True,'buildId':buildid,'checks':findings}
