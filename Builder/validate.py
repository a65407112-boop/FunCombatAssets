"""Offline structural checks. This module never inspects model geometry."""
from pathlib import Path
import hashlib,json,re,zlib
from lxml import etree as E

def require(condition,message):
    if not condition:raise ValueError(message)

def serialized_property_value(element):
    # A model export has no inherited document namespace declarations. Compare
    # the exact property structure and opaque text, excluding formatting tails.
    if element is None:return None
    return (element.tag,sorted(element.attrib.items()),element.text,
            tuple(serialized_property_value(child) for child in element))

def binary_property_types(source,output):
    from model_io import binary_property_schema
    original=binary_property_schema(source);encoded=binary_property_schema(output)
    compared={key for key in encoded if key in original}
    differences=[f'{cls}.{name}: source type {original[cls,name]}, exported type {encoded[cls,name]}'
                 for cls,name in sorted(compared) if original[cls,name]!=encoded[cls,name]]
    require(not differences,'Binary property type mismatch: '+'; '.join(differences))
    return {'passed':True,'propertiesCompared':len(compared),
            'spawnTeamColorType':encoded.get(('SpawnLocation','TeamColor')),
            'intValueValueType':encoded.get(('IntValue','Value'))}

def references(tree,label):
    items=list(tree.iter('Item'));ids=[e.get('referent') for e in items]
    require(len(ids)==len(set(ids)),label+': duplicate referents')
    known=set(ids)
    for p in tree.iter('Ref'):require(p.text in known or p.text in {'null','nil',None},label+': unresolved reference '+str(p.text))
    shared={e.get('md5') for e in tree.findall('SharedStrings/SharedString')}
    for p in tree.iter('Item'):
        for s in p.findall('Properties/SharedString'):require(s.text in shared or not s.text,label+': missing shared data')
    return len(items)

def spawn_initialization(tree):
    starter=tree.find('Item[@class="StarterPlayer"]')
    require(starter is not None,'StarterPlayer is missing')
    require(starter.findtext('Properties/bool[@name="LoadCharacterAppearance"]')=='false',
            'Engine avatar loading must not race the server R6 preparation')
    rigs=starter.xpath('./Item[Properties/string[@name="Name"]="StarterCharacter"]')
    require(len(rigs)==1,'Original StarterCharacter is missing/duplicate')
    rig=rigs[0];hum=rig.find('Item[@class="Humanoid"]')
    require(hum is not None,'Original R6 Humanoid is missing')
    require(hum.findtext('Properties/bool[@name="RequiresNeck"]')=='false','R6 neck death protection must precede appearance loading')
    require(hum.findtext('Properties/bool[@name="BreakJointsOnDeath"]')=='false','Original R6 joints must survive initialization')
    parts={e.findtext('Properties/string[@name="Name"]'):e for e in rig.findall('Item')}
    for name in ('HumanoidRootPart','Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'):
        require(name in parts,'Original R6 body part missing: '+name)
    root=parts['HumanoidRootPart']
    require(root.findtext('Properties/bool[@name="Anchored"]')=='true','Initial R6 template can fall before CharacterAdded setup')
    require(rig.findtext('Properties/Ref[@name="PrimaryPart"]')==root.get('referent'),'Original R6 primary root is not connected')
    body_ids={e.get('referent') for e in rig.iter('Item')}
    motors=[e for e in rig.iter('Item') if e.get('class')=='Motor6D']
    require(len(motors)==6,'Original R6 motor connections are missing')
    for motor in motors:
        for key in ('Part0','Part1'):
            require(motor.findtext('Properties/Ref[@name="'+key+'"]') in body_ids,'R6 motor refers outside the original character')
    workspace=tree.find('Item[@class="Workspace"]')
    maps=workspace.xpath('./Item[Item/Properties/string[@name="Name"]="IsMap"]')
    require(len(maps)==1,'Exactly one original map must be active at startup')
    spawns=maps[0].xpath('./Item[Properties/string[@name="Name"]="Spawns"]/Item[@class="SpawnLocation"]')
    enabled=[p for p in spawns if p.findtext('Properties/bool[@name="Enabled"]','true')=='true']
    require(enabled,'The active original map has no enabled spawn locations')
    initial_map=maps[0].findtext('Properties/string[@name="Name"]')
    data_modules=tree.xpath('./Item[@class="ServerScriptService"]/Item[Properties/string[@name="Name"]="FunCombatServer"]/Item[Properties/string[@name="Name"]="WorldData"]')
    require(len(data_modules)==1,'Generated WorldData is missing')
    initial=re.findall(r'\["initialMap"\]=("(?:[^"\\]|\\.)*")',data_modules[0].findtext('Properties/*[@name="Source"]',''))
    require(len(initial)==1 and json.loads(initial[0])==initial_map,'WorldData initial map differs from the original active map')
    templates=tree.xpath('./Item[@class="ServerStorage"]/Item[Properties/string[@name="Name"]="FunCombatData"]/Item[Properties/string[@name="Name"]="Maps"]/Item')
    matching=[p for p in templates if p.get('class')=='Model' and p.findtext('Properties/string[@name="Name"]')==initial_map]
    require(len(matching)==1,'Original initial map template is missing/duplicate')
    template_spawns=matching[0].xpath('./Item[Properties/string[@name="Name"]="Spawns"]/Item[@class="SpawnLocation"]')
    require(any(p.findtext('Properties/bool[@name="Enabled"]','true')=='true' for p in template_spawns),'Original initial map template has no enabled spawns')
    return {'passed':True,'initialMap':initial_map,
            'enabledSpawnLocations':len(enabled),'r6Motors':len(motors),
            'sourceTemplateHeldUntilPrepared':True,'engineAppearanceRaceDisabled':True,
            'initialMapMetadataAndTemplate':True}

def validate(output):
    output=Path(output);repo=output/'GitHub'
    protocol=json.loads((repo/'config/protocol.json').read_text())
    catalog=json.loads((repo/'config/assets.json').read_text())
    manifest=json.loads((repo/'manifest.json').read_text())
    identifiers=json.loads((repo/'config/identifiers.json').read_text())
    from build import read_admin_settings
    admin=read_admin_settings(repo)
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
    spawn_setup=spawn_initialization(xml)
    items=list(xml.iter('Item'));byname={}
    for e in items:byname.setdefault(e.findtext('Properties/string[@name="Name"]'),[]).append(e)
    for key,name in protocol['names'].items():
        require(len(byname.get(name,[]))==1,'Network identifier is missing/duplicate: '+key)
        e=byname[name][0]
        expected='Folder' if key=='Folder' else protocol['instances'][name]
        require(e.get('class')==expected,'Network class mismatch: '+key)
    require(byname[protocol['names']['Version']][0].findtext('Properties/int64[@name="Value"]')=='4','Wrong encoded version value/type')
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
    nodes=0;csg=0;asset_refs=set();expected_native={};expected_meshes={};expected_surfaces={}
    banned={'Script','LocalScript','ModuleScript','RemoteEvent','RemoteFunction','BindableEvent','BindableFunction'}
    for key,entry in catalog['packages'].items():
        package=json.loads((repo/entry['path']).read_text());ids={n['id'] for n in package['nodes']}
        require(len(ids)==len(package['nodes'])==entry['count'],'Node membership/count mismatch: '+key)
        require(package['root'] in ids and not package['externalReferences'],'Unresolved package: '+key)
        for n in package['nodes']:
            require(n['class'] not in banned,'Executable presentation asset: '+key)
            require(n['parent'] is None or n['parent'] in ids,'Missing asset parent: '+key)
            for name,p in n['properties'].items():
                require(n['class']!='WeldConstraint' or name not in {'Part0Internal','Part1Internal'},'Internal serialized weld member escaped into runtime JSON: '+key)
                if p['type']=='Ref':require(p['value'] is None or p['value'] in ids,'Missing asset reference: '+key+'/'+name)
                if name in {'MeshId','TextureId','TextureID','SoundId','AnimationId','Image','Texture'} and p['value']:asset_refs.add(str(p['value']))
            if n['class']=='UnionOperation':
                csg+=1;expected_native[str(n['id'])]=catalog['nativeCSG']['nodes'].get(str(n['id']))
                require(expected_native[str(n['id'])],'Embedded CSG lacks original native dependency: '+key)
            elif n['class']=='MeshPart':
                name=catalog['nativeMeshes']['nodes'].get(str(n['id']))
                require(name,'Original MeshPart lacks native load state: '+key)
                expected_meshes[str(n['id'])]=name
            elif n['class']=='SurfaceAppearance':
                surface_entry=catalog['nativeMeshes']['surfaces'].get(str(n['id']))
                require(surface_entry and surface_entry['meshId']==str(n['parent']),'Original PBR dependency host differs: '+key)
                expected_surfaces[str(n['id'])]=surface_entry
        model=E.parse(str(repo/entry['modelPath'])).getroot()
        require(references(model,key)==entry['count'],'Model/JSON membership mismatch: '+key)
        for union in model.iter('Item'):
            if union.get('class')!='UnionOperation':continue
            source_id=str(int(union.get('referent').removeprefix('RBXSRC')))
            native=byname.get(expected_native[source_id],[])
            require(len(native)==1 and native[0].get('class')=='UnionOperation','Original native CSG missing/duplicate: '+source_id)
            native=native[0]
            require(not native.findall('Item'),'Native CSG retains exported descendants: '+source_id)
            # Byte comparisons of opaque payload fields do not inspect geometry.
            for field in union.findall('Properties/BinaryString')+union.findall('Properties/SharedString'):
                other=native.find('Properties/*[@name="'+field.get('name')+'"]')
                require(other is not None and other.tag==field.tag and other.text==field.text,'Original opaque CSG data differs: '+source_id)
        for original in model.iter('Item'):
            if original.get('class') not in {'MeshPart','SurfaceAppearance'}:continue
            source_id=str(int(original.get('referent').removeprefix('RBXSRC')))
            name=expected_meshes[source_id] if original.get('class')=='MeshPart' else expected_surfaces[source_id]['name']
            native=byname.get(name,[])
            require(len(native)==1 and native[0].get('class')==original.get('class'),'Original native mesh/PBR missing or wrong class: '+source_id)
            native=native[0]
            # Compare serialized properties as opaque data, never vertex/shape geometry.
            for field in original.findall('Properties/*'):
                if field.get('name') in {'Name','Archivable'}:continue
                other=native.find('Properties/*[@name="'+field.get('name')+'"]')
                require(other is not None and serialized_property_value(other)==serialized_property_value(field),'Original native mesh/PBR property differs: '+source_id+'/'+field.get('name'))
            if original.get('class')=='SurfaceAppearance':
                host=expected_meshes[expected_surfaces[source_id]['meshId']]
                require(native.getparent().get('class')=='MeshPart' and native.getparent().findtext('Properties/string[@name="Name"]')==host,'Native PBR has an invalid host: '+source_id)
            else:
                require(all(child.get('class')=='SurfaceAppearance' for child in native.findall('Item')),'Native MeshPart retains nonessential presentation children: '+source_id)
        nodes+=entry['count']
    dependency=catalog['nativeCSG'];require(dependency['nodes']==expected_native,'Native dependency manifest differs from original union membership')
    native_folders=byname.get(dependency['folder'],[])
    require(len(native_folders)==1 and native_folders[0].get('class')=='Folder','Encoded native dependency folder missing/duplicate')
    require(native_folders[0].getparent().get('class')=='ReplicatedStorage','Native CSG folder is not replicated')
    require({e.findtext('Properties/string[@name="Name"]') for e in native_folders[0].findall('Item')}==set(expected_native.values()),'Unexpected native presentation dependencies')
    mesh_dependency=catalog['nativeMeshes']
    require(mesh_dependency['nodes']==expected_meshes and mesh_dependency['surfaces']==expected_surfaces,'Native mesh/PBR manifest differs from source membership')
    mesh_folders=byname.get(mesh_dependency['folder'],[])
    require(len(mesh_folders)==1 and mesh_folders[0].get('class')=='Folder' and mesh_folders[0].getparent().get('class')=='ReplicatedStorage','Native mesh dependency folder missing or wrong location')
    require({e.findtext('Properties/string[@name="Name"]') for e in mesh_folders[0].findall('Item')}==set(expected_meshes.values()),'Unexpected native mesh dependency membership')
    kohl=byname.get("Kohl's Admin Infinite",[])
    require(len(kohl)==1 and kohl[0].get('class')=='Script' and kohl[0].getparent().get('class')=='ServerScriptService','Native Kohl loader hierarchy missing/duplicate')
    require(kohl[0].findtext('Properties/bool[@name="Disabled"]')=='true','Native Kohl Credit must be started once by reviewed wrapper')
    require('1868400649' in kohl[0].findtext('Properties/*[@name="Source"]',''),'Original Kohl dependency ID missing')
    kohl_children={e.findtext('Properties/string[@name="Name"]'):e for e in kohl[0].findall('Item')}
    require(set(kohl_children)=={'Settings','Custom Commands'} and all(e.get('class')=='ModuleScript' for e in kohl_children.values()),'Original Kohl settings/custom modules missing')
    require('.commands(bridge)' in kohl_children['Custom Commands'].findtext('Properties/*[@name="Source"]',''),'Native game dummy command bridge missing')
    owner=admin['ownerUserId']
    settings_source=kohl_children['Settings'].findtext('Properties/*[@name="Source"]','')
    require('local ownerUserId='+str(owner)+'\n' in settings_source,'Configured account missing from native Kohl Owners')
    runtime=next((e for e in items if e.get('class')=='Folder' and e.findtext('Properties/string[@name="Name"]')=='FunCombatServer'),None)
    require(runtime is not None,'Server runtime is missing')
    generated={e.findtext('Properties/string[@name="Name"]'):e.findtext('Properties/*[@name="Source"]','') for e in runtime.findall('Item')}
    require('["ownerUserId"]='+str(owner) in generated['Config'],'Server owner identity differs from builder settings')
    require('end,10,Config.ownerUserId)' in generated['Main'],'Server access does not use configured owner identity')
    require(manifest['dependencies']['avatar_content']==['cleanup','networking','state'] and 'avatar_content' in manifest['dependencies']['preload'],'Avatar content observer must initialize before resource warmup')
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
    binary_types=binary_property_types(output/'Source/FunCombat_Original.rbxl',output/'funcombat_server.rbxl')
    return {'passed':True,'checks':['input checksum','manifest SHA256/Adler32/bytes','dependency DAG',
        'XML referents/shared data','encoded protocol/build identity','network instance counts','native prompt templates',
        'asset hierarchy and public WeldConstraint refs','original costume native CSG dependencies and opaque payload fidelity','original native MeshPart load state and PBR property/host fidelity','native original Kohl hierarchy and dummy command bridge','same explicit numeric owner in server and native Kohl settings','actual avatar content observer dependency order','all 47 source animations','binary rbxl header','binary property type IDs match original','safe R6 template and active original spawns'],
        'binaryPropertyTypes':binary_types,
        'spawnInitialization':spawn_setup,
        'nativeOriginalCSGDependencies':len(expected_native),'nativeOriginalMeshPartDependencies':len(expected_meshes),'nativeOriginalPBRDependencies':len(expected_surfaces),'originalKohlAssetId':1868400649,'configuredOwnerUserId':owner,
        'serverInstances':count,'prompts':len(prompts),'packages':len(catalog['packages']),'packageNodes':nodes,
        'embeddedCostumeCSG':csg,'animations':47,'keyframes':keyframes,'poses':poses,'hostedReferenceCount':len(asset_refs),
        'geometryInspected':False,'robloxEngineTested':False,'legacyClientTested':False,
        'hostedAssetPermissionsTested':False,'executorModelBackendTested':False}
