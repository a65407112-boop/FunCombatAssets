"""Export native world presentation without examining avatar/morph packages."""
from __future__ import annotations
import argparse
import base64
import copy
import hashlib
import json
import re
import shutil
import struct
import subprocess
from pathlib import Path

from lxml import etree as E
import build as base
from luau_pack import pack, restore
from native_r6_upgrade import literal_table
from model_io import (Source, binary_property_schema, decode_attributes, dump,
                      repository_files, sha, validate_saved_scalar_types, repair_place_services,
                      complete_reference_properties, validate_saved_reference_types, repair_saved_unique_ids)

PARTS={'Part','WedgePart','CornerWedgePart','TrussPart','MeshPart','UnionOperation',
       'NegateOperation','SpawnLocation','Seat','VehicleSeat'}
EXECUTABLES={'Script','LocalScript','ModuleScript','RemoteEvent','RemoteFunction',
             'BindableEvent','BindableFunction'}
HIDDEN_EFFECTS={'SurfaceGui','BillboardGui','ScreenGui','ParticleEmitter','Trail','Beam','Highlight'}
COLLISION_PROPERTIES={'CFrame','size','Size','CanCollide','CanTouch','CanQuery','Anchored',
    'CollisionFidelity','CollisionGroupId','CollisionGroup','shape','Shape',
    'PhysicsData','MeshData','ChildData','MeshId','MeshContent','InitialSize'}


def attributes(item, values):
    encoded=bytearray(struct.pack('<I',len(values)))
    def string(value):
        value=value.encode('utf8');return struct.pack('<I',len(value))+value
    for key,value in sorted(values.items()):
        encoded.extend(string(key))
        if isinstance(value,bool):encoded.extend(bytes([3,int(value)]))
        elif isinstance(value,(int,float)):encoded.extend(b'\x06'+struct.pack('<d',value))
        elif isinstance(value,str):encoded.extend(b'\x02'+string(value))
        else:raise ValueError('Unsupported existing world attribute: '+key)
    base.set_property(item,'AttributesSerialize','BinaryString',base64.b64encode(encoded).decode())


def add_attribute(item,key,value):
    values=decode_attributes(item.findtext('Properties/BinaryString[@name="AttributesSerialize"]'))
    values[key]=value;attributes(item,values)


def hide_presentation(root):
    for item in root.iter('Item'):
        cls=item.get('class')
        if cls in PARTS:
            base.set_property(item,'Transparency','float','1')
            base.set_property(item,'CastShadow','bool','false')
        elif cls in {'Decal','Texture'}:base.set_property(item,'Transparency','float','1')
        elif cls in HIDDEN_EFFECTS:base.set_property(item,'Enabled','bool','false')


def presentation_copy(root):
    root=copy.deepcopy(root)
    for item in list(root.iter('Item')):
        if item.get('class') in EXECUTABLES:
            item.getparent().remove(item)
    known={item.get('referent') for item in root.iter('Item')}
    for prop in root.iter('Ref'):
        if prop.text not in known:prop.text='null'
    return root


def waiting_room():
    room=base.instance('Model',base.code_id('client-world','WaitingRoom'))
    base.set_property(room,'Archivable','bool','true')
    base.set_property(room,'PrimaryPart','Ref','null')
    # The interior has a 48x48 floor, four walls and a roof; no text or UI.
    surfaces=[('Floor',(0,1000,0),(50,2,50)),('Roof',(0,1024,0),(50,2,50)),
        ('Left',(-25,1012,0),(2,24,50)),('Right',(25,1012,0),(2,24,50)),
        ('Front',(0,1012,-25),(50,24,2)),('Back',(0,1012,25),(50,24,2))]
    for label,position,size in surfaces+[('WaitingSpawn',(0,1002,0),(6,1,6))]:
        spawn=label=='WaitingSpawn'
        item=base.instance('SpawnLocation' if spawn else 'Part',base.code_id('client-world',label))
        base.set_property(item,'Archivable','bool','true')
        base.set_property(item,'Anchored','bool','true')
        base.set_property(item,'CanCollide','bool','false' if spawn else 'true')
        base.set_property(item,'CanTouch','bool','false')
        base.set_property(item,'CanQuery','bool','false' if spawn else 'true')
        base.set_property(item,'Transparency','float','1' if spawn else '0')
        base.set_property(item,'shape','token',1)
        base.set_property(item,'formFactorRaw','token',3)
        base.set_property(item,'Material','token',256)
        base.set_property(item,'Color3uint8','Color3uint8',0x5D636D)
        cf=E.SubElement(item.find('Properties'),'CoordinateFrame',name='CFrame')
        for key,value in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],[*position,1,0,0,0,1,0,0,0,1]):
            E.SubElement(cf,key).text=str(value)
        vec=E.SubElement(item.find('Properties'),'Vector3',name='size')
        for key,value in zip('XYZ',size):E.SubElement(vec,key).text=str(value)
        if spawn:
            base.set_property(item,'Enabled','bool','true');base.set_property(item,'Neutral','bool','true')
            base.set_property(item,'Duration','float','0')
        room.append(item)
    return room


def collision_signature(root):
    def value(prop):
        return (prop.tag,(prop.text or '').strip(),tuple((c.tag,(c.text or '').strip()) for c in prop))
    return [(item.get('class'),sorted((p.get('name'),value(p)) for p in item.findall('Properties/*')
                                   if p.get('name') in COLLISION_PROPERTIES))
            for item in root.iter('Item') if item.get('class') in PARTS]


def encode(tree,xml,binary,rbxmk,format):
    complete_reference_properties(tree)
    xml.write_bytes(E.tostring(tree,encoding='utf8'))
    script=xml.parent/'encode.lua'
    script.write_text('local a,b,c,d=...\nfs.write(b,fs.read(a,c),d)\n')
    # RBXM and RBXL use the same binary container. rbxmk 0.9.1's model-mode
    # encoder panics without a descriptor on these native map properties.
    # Encode the single Model/Folder root through its lossless place-mode path;
    # the result contains no service instances and is also decoded as RBXM below.
    result=subprocess.run([str(Path(rbxmk).resolve()),'run','--allow-insecure-paths',str(script),
                    str(xml),str(binary),'rbxlx','rbxl'],
                   check=True,capture_output=True,timeout=120)
    if not binary.is_file() or binary.stat().st_size<32:
        raise RuntimeError('Native encoder produced no model: '+result.stderr.decode(errors='replace'))
    if format=='rbxl':
        repair_place_services(binary,{item.get('class') for item in tree.findall('Item')})
        repair_saved_unique_ids(binary)
    validate_saved_reference_types(binary)


def upgrade(source_path,repo,output,rbxmk):
    repo=Path(repo).resolve();output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    source=Source(source_path,rbxmk,output/'cache');tree=source.tree
    identifiers=json.loads((repo/'config/identifiers.json').read_text())
    protocol=json.loads((repo/'config/protocol.json').read_text())
    manifest=json.loads((repo/'manifest.json').read_text())
    catalog=json.loads((repo/'config/assets.json').read_text())
    names=identifiers['names'];labels=identifiers['objectNames']
    def find(parent,label):
        return next(x for x in parent.findall('Item') if Source.name(x)==names[label])
    ws=tree.find('Item[@class="Workspace"]');storage=tree.find('Item[@class="ServerStorage"]')
    data=find(storage,'FunCombatData');maps=find(data,'Maps')
    runtime=find(tree.find('Item[@class="ServerScriptService"]'),'FunCombatServer')
    if any(Source.name(x)==base.code_id('client-world','ClientWorldSession') for x in runtime.findall('Item')):
        raise ValueError('Use the saved layout 6 baseline as input; this server already contains the world upgrade')
    map_aliases=set(identifiers['mapNames'].values()) if 'mapNames' in identifiers else {names[x] for x in ('Crossroads','OriginalMap')}
    active=[x for x in ws.findall('Item') if Source.name(x) in map_aliases]
    map_roots=active+maps.findall('Item')
    if not active or len({Source.name(x) for x in map_roots})!=2:raise ValueError('Expected two original maps')
    excluded={'Terrain','Camera','Configuration','BloomEffect','ColorCorrectionEffect','SunRaysEffect'}
    static=[x for x in ws.findall('Item') if x not in active and x.get('class') not in excluded]
    roots=map_roots+static
    before_geometry=[collision_signature(x) for x in roots]
    schema=binary_property_schema(source_path)
    settings_before=E.tostring(tree.find('Item[@class="StarterPlayer"]'))
    saved_scripts={Source.name(x):x.findtext('Properties/*[@name="Source"]') for x in tree.iter('Item')
                   if x.get('class') in {'Script','ModuleScript','LocalScript'}}
    config={'version':1,'remote':base.code_id('client-world','WorldSession'),
        'readyAttribute':base.code_id('client-world','Participant'),
        'nodeAttribute':base.code_id('client-world','Node'),
        'room':base.code_id('client-world','WaitingRoom'),'spawn':base.code_id('client-world','WaitingSpawn'),
        'lease':15,'maps':{},'staticAsset':'world/Environment',
        'staticRoots':[{'alias':Source.name(x),'nodeId':source.reverse[x.get('referent')]} for x in static]}
    labels.update({config['remote']:'WorldSession',config['room']:'WaitingRoom',config['spawn']:'WaitingSpawn'})
    for root in roots:
        for item in root.iter('Item'):
            add_attribute(item,config['nodeAttribute'],source.reverse[item.get('referent')])
    exports=[]
    def export(root,key,wrapper_id=None):
        native=presentation_copy(root);nodes=[]
        for item in native.iter('Item'):
            ref=item.get('referent');id=wrapper_id if item is native and wrapper_id is not None else source.reverse[ref]
            add_attribute(item,catalog['nativeNodeAttribute'],id)
            parent=item.getparent()
            parent_id=None if item is native else wrapper_id if parent is native and wrapper_id is not None else source.reverse[parent.get('referent')]
            nodes.append({'id':id,'class':item.get('class'),'name':Source.name(item),'parent':parent_id,'properties':{},'attributes':{}})
        payload={'version':1,'root':nodes[0]['id'],'nodes':nodes,'externalReferences':[]}
        stem=key.replace('/','_')
        json_path='assets/world/'+stem+'.json';model_path='assets/world/'+stem+'.rbxm'
        dump(repo/json_path,payload)
        document=E.Element('roblox',version='4')
        E.SubElement(document,'External').text='null';E.SubElement(document,'External').text='nil'
        document.append(native)
        shared=tree.find('SharedStrings')
        if shared is not None:document.append(copy.deepcopy(shared))
        (repo/model_path).parent.mkdir(parents=True,exist_ok=True)
        encode(document,output/(stem+'.rbxmx'),repo/model_path,rbxmk,'rbxm')
        decoded=Source(repo/model_path,rbxmk,output/('check-'+stem))
        if len(decoded.by)!=len(nodes):raise ValueError('Export changed model node count: '+key)
        if any(x.get('class') in EXECUTABLES for x in decoded.tree.iter('Item')):raise ValueError('Executable exported: '+key)
        actual=binary_property_schema(repo/model_path)
        mismatches=[k for k,v in actual.items() if k in schema and schema[k]!=v]
        if mismatches:raise ValueError('Native model property types changed: '+repr(mismatches))
        catalog['packages'][key]={'path':json_path,'modelPath':model_path,'modelFormat':'rbxm',
            'backend':'model','count':len(nodes),'preload':False,'sha256':sha(repo/json_path)}
        exports.append({'key':key,'instances':len(nodes),'bytes':(repo/model_path).stat().st_size,
                        'nativeTypesPreserved':True,'scriptFree':True})
    seen=set()
    for root in map_roots:
        alias=Source.name(root);key='world/'+labels.get(alias,next((k for k,v in names.items() if v==alias),alias))
        config['maps'][alias]=key
        if alias not in seen:export(root,key);seen.add(alias)
    environment=base.instance('Folder',base.code_id('client-world','Environment'))
    for root in static:environment.append(copy.deepcopy(root))
    export(environment,config['staticAsset'],90000000)
    for root in roots:hide_presentation(root)
    ws.append(waiting_room())
    for item in ws[-1].iter('Item'):
        if Source.name(item) not in labels:
            for label in ('Floor','Roof','Left','Right','Front','Back'):
                if Source.name(item)==base.code_id('client-world',label):labels[Source.name(item)]='WaitingRoom'+label
    modules={label:find(runtime,label) for label in ('Main','Config')}
    for label,body in [('ClientWorldSession',(repo/'Builder/templates/server/ClientWorldSession.lua').read_text()),
                       ('ClientWorldData','return '+base.lua(config))]:
        alias=base.code_id('client-world',label);names[label]=alias;labels[alias]=label
        item=base.instance('ModuleScript',alias);base.set_property(item,'Source','ProtectedString',pack(body));runtime.append(item)
    main=restore(modules['Main'].findtext('Properties/*[@name="Source"]'))
    anchor='local world = World . new ( combat , templates )'
    if main.count(anchor)!=1:raise ValueError('Unknown main world initialization')
    main=main.replace(anchor,anchor+' local clientWorldSession = require ( script . Parent [ '+base.lua(names['ClientWorldSession'])+' ] ) . start ( world , net , Config . buildId , require ( script . Parent [ '+base.lua(names['ClientWorldData'])+' ] ) )')
    base.set_property(modules['Main'],'Source','ProtectedString',pack(main))
    build_id=hashlib.sha256((source.sha+main+base.lua(config)+''.join((repo/p).read_text() for p in
        ['Builder/client_world_upgrade.py','Builder/templates/server/ClientWorldSession.lua',
         'client/world.lua','client/participants.lua','client/assets.lua','client/preload.lua','loader.lua'])).encode()).hexdigest()[:24]
    server_config=literal_table(restore(modules['Config'].findtext('Properties/*[@name="Source"]')))
    server_config['buildId']=build_id;base.set_property(modules['Config'],'Source','ProtectedString',pack('return '+base.lua(server_config)))
    net=find(tree.find('Item[@class="ReplicatedStorage"]'),'FunCombatNetwork') if 'FunCombatNetwork' in names else next(
        x for x in tree.find('Item[@class="ReplicatedStorage"]').findall('Item') if Source.name(x)==protocol['names']['Folder'])
    value=next(x for x in net.findall('Item') if Source.name(x)==protocol['names']['BuildId'])
    base.set_property(value,'Value','string',build_id)
    binary=output/'funcombat_server.rbxl'
    encode(tree,output/'client-world.rbxlx',binary,rbxmk,'rbxl')
    scalar=validate_saved_scalar_types(binary);actual_schema=binary_property_schema(binary)
    mismatches=[k for k,v in actual_schema.items() if k in schema and schema[k]!=v]
    if mismatches:raise ValueError('Server native property types changed: '+repr(mismatches))
    decoded=Source(binary,rbxmk,output/'roundtrip')
    decoded_names={Source.name(x):x for x in decoded.tree.iter('Item')}
    decoded_nodes={int(value):x for x in decoded.tree.iter('Item')
        if (value:=decode_attributes(x.findtext('Properties/BinaryString[@name="AttributesSerialize"]')).get(config['nodeAttribute'])) is not None}
    if before_geometry!=[collision_signature(decoded_nodes[source.reverse[x.get('referent')]]) for x in roots]:
        raise ValueError('Server collision geometry changed')
    if settings_before!=E.tostring(tree.find('Item[@class="StarterPlayer"]')):raise ValueError('Player settings were modified')
    changes=[]
    for label,body in saved_scripts.items():
        current=decoded_names[label].findtext('Properties/*[@name="Source"]')
        if body!=current:changes.append(label)
    if set(changes)!={names['Main'],names['Config']}:raise ValueError('Unrelated runtime source changed: '+repr(changes))
    service_roots=set(decoded.tree.findall('Item'))
    for item in decoded.tree.iter('Item'):
        if item in service_roots or item.get('class') in {'Terrain','StarterPlayerScripts','StarterCharacterScripts'} or Source.name(item) in {'Settings','Custom Commands','Custom_Commands'}:continue
        if not re.fullmatch('[0-9a-f]{12}',Source.name(item)):raise ValueError('Readable saved name: '+Source.name(item))
    protocol.update({'buildId':build_id,'layoutVersion':7,'clientWorld':config,
        'layout':'GitHub client-visible maps; invisible server collision; closed waiting room; native R6'})
    identifiers.update({'layoutVersion':7,'scope':'Opaque saved names; external visible world; native R6 and local readable names.'})
    dump(repo/'config/protocol.json',protocol);dump(repo/'config/identifiers.json',identifiers);dump(repo/'config/assets.json',catalog)
    manifest.update({'buildId':build_id,'layoutVersion':7,'buildStatus':'Client world; offline checks; live Roblox/executor test required'})
    modules_order=[x for x in manifest['modules'] if x not in {'world','participants'}]
    manifest['modules']=modules_order
    index=modules_order.index('labels')+1
    modules_order[index:index]=['participants','world']
    manifest['dependencies']['participants']=['cleanup']
    manifest['dependencies']['world']=['cleanup','assets','networking','labels','participants']
    shutil.copy2(binary,repo/'server/funcombat_server.rbxl')
    report={'passed':True,'buildId':build_id,'serverSha256':sha(binary),'baseServerSha256':source.sha,
        'serverInstances':len(decoded.by),'exports':exports,'collisionPartsPreserved':sum(len(x) for x in before_geometry),
        'collisionGeometryUnchanged':True,'eligibleNamesOpaque':True,'unrelatedRuntimeSourcesUnchanged':True,
        'morphBehaviorInspected':False,'morphFilesChanged':False,'nativeScalarPropertiesChecked':scalar['propertiesChecked'],
        'robloxStudioTested':False,'executorTested':False,'multiplayerPhysicsTested':False,'publishedToRoblox':False}
    dump(repo/'Client_World_Checks.json',report)
    manifest['files']=repository_files(repo);dump(repo/'manifest.json',manifest)
    return report


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--repo',required=True)
    p.add_argument('--output',required=True);p.add_argument('--rbxmk',required=True)
    args=p.parse_args();print(json.dumps(upgrade(args.source,args.repo,args.output,args.rbxmk),indent=2))
