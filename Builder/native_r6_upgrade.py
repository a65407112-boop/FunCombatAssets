"""Upgrade the checked server DOM without requiring the unavailable source place.

Only hierarchy, names, references and scripts are edited. Native map payloads
are retained as opaque values. rbxmk is used for binary conversion.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import shutil
import struct
import base64
import subprocess
from pathlib import Path

from lxml import etree as E

import build as base
from compact import DATA_DOTS, STATS, replace_once, rewrite_bindings
from luau_pack import pack, restore, string_bytes, tokens
from model_io import Source, dump, repository_files, sha, SAVED_SCALAR_TYPES, validate_saved_scalar_types, repair_place_services, complete_reference_properties, validate_saved_reference_types


def literal_table(code):
    """Read data-only Lua tables; never execute source from the place."""
    parts=tokens(code)
    pos=0

    def take(want=None):
        nonlocal pos
        if pos>=len(parts):
            raise ValueError('Truncated Lua data')
        kind,value=parts[pos]
        pos+=1
        if want is not None and value!=want:
            raise ValueError('Expected '+want+', got '+value)
        return kind,value

    def value():
        kind,text=take()
        if kind=='string':
            return string_bytes(text).decode('utf8')
        if text=='{':
            entries=[]
            while pos<len(parts) and parts[pos][1]!='}':
                key=None
                if parts[pos][1]=='[':
                    take('[');key=value();take(']');take('=')
                entries.append((key,value()))
                if parts[pos][1] not in {',',';'}:
                    break
                take()
            take('}')
            if not entries:
                return {}
            if all(k is None for k,_ in entries):
                return [v for _,v in entries]
            if any(k is None for k,_ in entries):
                raise ValueError('Mixed Lua data table')
            result={}
            for key,item in entries:
                if key in result:
                    raise ValueError('Duplicate Lua data key')
                result[key]=item
            return result
        if text in {'true','false','nil'}:
            return {'true':True,'false':False,'nil':None}[text]
        if text=='-':
            parsed=value()
            if type(parsed) not in {int,float}:
                raise ValueError('Invalid numeric data')
            return -parsed
        if re.fullmatch(r'\d+|\d*\.\d+(?:[eE][+-]?\d+)?|\d+[eE][+-]?\d+',text):
            return float(text) if any(c in text for c in '.eE') else int(text)
        raise ValueError('Executable/nonliteral Lua data: '+text)

    take('return')
    result=value()
    if pos!=len(parts) or not isinstance(result,(dict,list)):
        raise ValueError('Expected one returned literal table')
    return result


def native_settings(tree):
    starter=tree.find('Item[@class="StarterPlayer"]')
    if starter is None:
        raise ValueError('StarterPlayer is missing')
    for item in list(starter.findall('Item')):
        if item.get('class')=='Model' and Source.name(item)=='StarterCharacter':
            starter.remove(item)
    base.set_property(starter,'LoadCharacterAppearance','bool','true')
    base.set_property(starter,'GameSettingsAvatar','token',0)  # GameAvatarType.R6
    base.set_property(starter,'EnableDynamicHeads','token',2)
    # Keep the legacy Motor6D rig expected by the source animations/ragdoll.
    base.set_property(starter,'AvatarJointUpgrade_SerializedRollout','token',1)
    workspace=tree.find('Item[@class="Workspace"]')
    if workspace is not None:
        base.set_property(workspace,'AvatarUnificationMode','token',1)
        base.set_property(workspace,'MeshPartHeadsAndAccessories','token',2)


def property_xml(parent,key,prop,refs,serialized_tag=None):
    kind,value=prop['type'],prop.get('value')
    if kind=='Ref':
        E.SubElement(parent,'Ref',name=key).text=refs.get(value,'null')
        return
    if kind in {'string','bool','number','int','int64','token','BrickColor'}:
        if kind=='number' and serialized_tag not in {'float','double'}:
            raise ValueError('Missing native numeric property type: '+key)
        tag=serialized_tag or kind
        text=('true' if value else 'false') if kind=='bool' else str(value)
        E.SubElement(parent,tag,name=key).text=text
        return
    axes={'Vector3':['X','Y','Z'],'Color3':['R','G','B'],
          'CFrame':['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22']}
    if kind in axes:
        if serialized_tag=='Color3uint8':
            packed=(round(value[0]*255)<<16)|(round(value[1]*255)<<8)|round(value[2]*255)
            E.SubElement(parent,'Color3uint8',name=key).text=str(packed)
            return
        item=E.SubElement(parent,'CoordinateFrame' if kind=='CFrame' else kind,name=key)
        for field,number in zip(axes[kind],value):
            E.SubElement(item,field).text=str(number)
        return
    if kind=='PhysicalProperties':
        item=E.SubElement(parent,kind,name=key)
        E.SubElement(item,'CustomPhysics').text='false' if value is None else 'true'
        if value is not None:
            for field,number in zip(['Density','Friction','Elasticity','FrictionWeight','ElasticityWeight'],value):
                E.SubElement(item,field).text=str(number)
        return
    raise ValueError('Unsupported saved rig property '+kind+'/'+key)


def saved_rig(data,namespace,schema=None):
    refs={node['id']:'RBXNATIVE'+base.code_id(namespace,str(node['id'])) for node in data['nodes']}
    objects={}
    aliases={}
    for node in data['nodes']:
        item=E.Element('Item',{'class':node['class'],'referent':refs[node['id']]})
        properties=E.SubElement(item,'Properties')
        label=node['name']
        alias=base.code_id('native-rig-label',label)
        aliases[alias]=label
        E.SubElement(properties,'string',name='Name').text=alias
        for key,prop in node.get('properties',{}).items():
            if key in {'Name','Parent'}:
                continue
            fields=(schema or {}).get(node['class'],{})
            raw={'Size':'size','Shape':'shape','FormFactor':'formFactorRaw','Color':'Color3uint8'}.get(key,key)
            key=raw if raw in fields else key
            native=SAVED_SCALAR_TYPES.get((node['class'],key))
            property_xml(properties,key,prop,refs,native[0] if native else fields.get(key))
        attributes=node.get('attributes',{})
        if attributes:
            def string(text):
                raw=text.encode('utf8')
                return struct.pack('<I',len(raw))+raw
            raw=bytearray(struct.pack('<I',len(attributes)))
            for key,value in sorted(attributes.items()):
                raw+=string(key)
                if isinstance(value,bool): raw+=b'\x03'+bytes([value])
                elif isinstance(value,(float,int)): raw+=b'\x06'+struct.pack('<d',value)
                elif isinstance(value,str): raw+=b'\x02'+string(value)
                else: raise ValueError('Unsupported NPC attribute '+key)
            E.SubElement(properties,'BinaryString',name='AttributesSerialize').text=base64.b64encode(raw).decode()
        objects[node['id']]=item
    for node in data['nodes']:
        if node.get('parent') is not None:
            objects[node['parent']].append(objects[node['id']])
    return objects[data['root']],aliases


def adapt_combat(code,bindings):
    code='local Wire=require(script.Parent.WireCodec)\nlocal Bindings=require(script.Parent.Bindings)\n'+code
    code=replace_once(code,'if player then self.event:FireClient(player,id,data) else self.event:FireAllClients(id,data) end',
        'local encoded=Wire.transform(data,self.protocol.config.presentationEncode)\n    if player then self.event:FireClient(player,id,encoded) else self.event:FireAllClients(id,encoded) end')
    code=replace_once(code,'function(player,id,payload) self:request(player,id,payload) end',
        'function(player,id,payload) local ok,decoded=pcall(Wire.decodeAction,payload,self.protocol.config.presentationDecode) if ok then self:request(player,id,decoded) end end')
    code=replace_once(code,'return self:getSnapshot(player) end','return Wire.transform(self:getSnapshot(player),self.protocol.config.presentationEncode) end')
    code=replace_once(code,'r.character:SetAttribute(key,r[key]==true)','r.character:SetAttribute(Bindings.attributes[key] or key,r[key]==true)')
    return code.replace('{"Kills","Killstreak","Completions"}',base.lua([bindings['stats'][x] for x in ('Kills','Killstreak','Completions')]))


def map_digest(item):
    """Compare opaque map properties/references without interpreting geometry."""
    whole=item.getroottree().getroot()
    def stable_path(node):
        parts=[]
        while node is not None and node.tag=='Item':
            parent=node.getparent()
            siblings=parent.findall('Item')
            parts.append(node.get('class')+'#'+str(siblings.index(node)))
            node=parent
        return '/'.join(reversed(parts))
    external={x.get('referent'):stable_path(x) for x in whole.iter('Item')}
    result=copy.deepcopy(item)
    refs={node.get('referent'):str(i) for i,node in enumerate(result.iter('Item'))}
    for node in result.iter('Item'):
        node.set('referent',refs[node.get('referent')])
        name=node.find('Properties/*[@name="Name"]')
        if name is not None:
            name.getparent().remove(name)
        properties=node.find('Properties')
        if properties is not None:
            properties[:]=sorted(properties,key=lambda p:p.get('name',''))
    for prop in result.iter('Ref'):
        prop.text=refs.get(prop.text,external.get(prop.text,prop.text))
    return hashlib.sha256(E.tostring(result)).hexdigest()


def upgrade(source_path,repo,output,rbxmk):
    repo,output=Path(repo).resolve(),Path(output).resolve()
    output.mkdir(parents=True,exist_ok=True)
    cache=output/'.cache';cache.mkdir(exist_ok=True)
    identifiers=json.loads((repo/'config/identifiers.json').read_text())
    protocol=json.loads((repo/'config/protocol.json').read_text())
    source=Source(source_path,rbxmk,cache)
    tree=source.tree
    services={x.get('class'):x for x in tree.findall('Item')}
    runtime=next(x for x in services['ServerScriptService'].findall('Item') if Source.name(x)==identifiers['names']['FunCombatServer'])
    modules={label:next(x for x in runtime.findall('Item') if Source.name(x)==alias)
             for label,alias in identifiers['serverModules'].items()}
    readable={label:restore(item.findtext('Properties/*[@name="Source"]','')) for label,item in modules.items()}
    config=literal_table(readable['Config'])
    if config['buildId']!=protocol['buildId'] or config['version']!=5:
        raise ValueError('Input server and repository identities differ')
    rigs=literal_table(readable['RigData'])
    reverse={alias:name for name,alias in identifiers['names'].items()}
    for rig in rigs.values():
        for node in rig['nodes']:
            node['name']=reverse.get(node['name'],node['name'])
    names=identifiers['names']
    for label in ('DummyRig','InitialDummy'):
        names[label]=base.code_id('native-container',label)
    data=next(x for x in services['ServerStorage'].findall('Item') if Source.name(x)==names['FunCombatData'])
    maps=next(x for x in data.findall('Item') if Source.name(x)==names['Maps'])
    map_roots=[x for x in services['Workspace'].findall('Item') if x.get('class')=='Model']+maps.findall('Item')
    before_maps=[map_digest(x) for x in map_roots]
    before_models=sum(x.get('class')=='Model' for x in tree.iter('Item'))
    schema={}
    for item in tree.iter('Item'):
        fields=schema.setdefault(item.get('class'),{})
        for prop in item.findall('Properties/*'):
            fields[prop.get('name')]=prop.tag
    old_starters=sum(Source.name(x)=='StarterCharacter' and x.get('class')=='Model' for x in services['StarterPlayer'].findall('Item'))
    previous_templates=[x for x in data.findall('Item') if Source.name(x) in {names['InitialDummy'],names['DummyRig']}]
    for item in previous_templates:
        data.remove(item)
    native_settings(tree)
    rig_names={}
    for label,key in [('InitialDummy','initial'),('DummyRig','spawn')]:
        model,aliases=saved_rig(rigs[key],'saved-'+key,schema)
        base.set_property(model,'Name','string',names[label]);data.append(model)
        rig_names.update(aliases)
    object_names=dict(identifiers.get('objectNames',{}))
    object_names.update({alias:label for label,alias in names.items()})
    object_names.update(rig_names)
    for label,alias in protocol['names'].items():
        object_names[alias]='FunCombatNetwork' if label=='Folder' else label
    for label,definition in identifiers['prompts'].items():
        object_names[definition['name']]=label
    for alias,definition in identifiers.get('mapPrompts',{}).items():
        object_names[alias]=definition['path'].rsplit('/',1)[-1]
    required_classes={'Terrain','StarterPlayerScripts','StarterCharacterScripts'}
    upstream_names={'Settings','Custom Commands','Custom_Commands'}
    root_items=set(tree.findall('Item'))
    required=[]
    for item in tree.iter('Item'):
        name=Source.name(item)
        if item in root_items or item.get('class') in required_classes or name in upstream_names:
            required.append({'class':item.get('class'),'name':name})
            continue
        if not re.fullmatch('[0-9a-f]{12}',name):
            alias=base.code_id('native-saved-name',name)
            object_names[alias]=name
            base.set_property(item,'Name','string',alias)
    identifiers.update({'rigNames':rig_names,'objectNames':object_names,
        'layoutVersion':6,'scope':'Opaque saved names; native R6 player avatars; local readable names after external loader startup.'})
    bindings=literal_table(readable['Bindings'])
    bindings.update({'names':names,'rigNames':rig_names,'objectNames':object_names,'layoutVersion':6})
    attributes=identifiers['attributes']
    module_labels=set(identifiers['serverModules'])
    # New attribute literals share the same alias map in server and client.
    for label in ('Avatar','CombatServer'):
        raw=(repo/'Builder/templates/server'/f'{label}.lua').read_text()
        for match in re.finditer(r'(?:GetAttribute|SetAttribute|GetAttributeChangedSignal)\(\s*"([^"\n]+)"',raw):
            attributes.setdefault(match[1],base.code_id('compact-attribute',match[1]))
    readable['Avatar']=(repo/'Builder/templates/server/Avatar.lua').read_text()
    readable['CombatServer']=adapt_combat((repo/'Builder/templates/server/CombatServer.lua').read_text(),bindings)
    world=(repo/'Builder/templates/server/World.lua').read_text()
    world='local RigFactory=require(script.Parent.RigFactory)\nlocal Bindings=require(script.Parent.Bindings)\n'+world
    world=replace_once(world,'return self.templates.DummyRig:Clone()',
        'return RigFactory.clone(assert(self.templates:FindFirstChild("DummyRig"),"Saved NPC template is missing"),Bindings.rigNames)')
    world=replace_once(world,'self.activeMap=current\n                    return current',
        'self.activeMap=current\n                    local maps=self.templates:FindFirstChild("Maps")\n                    if maps and not maps:FindFirstChild(name) then local backup=assert(current:Clone(),"Initial map backup could not be cloned");backup.Parent=maps end\n                    return current')
    readable['World']=world
    main=(repo/'Builder/templates/server/Main.server.lua').read_text()
    anchor='local templates=assert(SS:FindFirstChild("FunCombatData"),"Source dependencies are missing")'
    main=replace_once(main,anchor,anchor+'\nlocal RigFactory=require(script.Parent.RigFactory)\nlocal Bindings=require(script.Parent.Bindings)\nlocal originalDummy=RigFactory.clone(assert(templates:FindFirstChild("InitialDummy"),"Saved initial NPC is missing"),Bindings.rigNames)\noriginalDummy.Name="DUMMY";originalDummy.Parent=workspace')
    readable['Main']=main
    readable['RigFactory']=(repo/'Builder/templates/server/RigFactory.lua').read_text()
    for label in ('Avatar','CombatServer','World','Main','RigFactory'):
        readable[label]=rewrite_bindings(readable[label],names,attributes,module_labels|DATA_DOTS|STATS)
    bindings['attributes']=attributes
    readable['Bindings']='return '+base.lua(bindings)
    seed=source.sha+''.join(k+v for k,v in sorted(readable.items()) if k!='Config')
    seed+=''.join(p.name+p.read_text() for p in sorted((repo/'client').glob('*.lua')))
    build_id=hashlib.sha256(seed.encode()).hexdigest()[:24]
    config['buildId']=build_id;readable['Config']='return '+base.lua(config)
    for label,body in readable.items():
        base.set_property(modules[label],'Source','ProtectedString',pack(body))
        (cache/(label+'.lua')).write_text(body)
    net=next(x for x in services['ReplicatedStorage'].findall('Item') if Source.name(x)==protocol['names']['Folder'])
    build_value=next(x for x in net.findall('Item') if Source.name(x)==protocol['names']['BuildId'])
    base.set_property(build_value,'Value','string',build_id)
    known={x.get('referent') for x in tree.iter('Item')}
    for prop in tree.iter('Ref'):
        if prop.text not in known and prop.text not in {'null','nil',None}:
            prop.text='null'
    if before_maps!=[map_digest(x) for x in map_roots]:
        raise ValueError('Upgrade changed opaque map properties or references')
    complete_reference_properties(tree)
    xml=output/'Game_Server.rbxlx';xml.write_bytes(E.tostring(tree,encoding='utf8'))
    converter=cache/'native_to_binary.lua'
    converter.write_text("local a,b=...\nfs.write(b,fs.read(a,'rbxlx'),'rbxl')\n")
    binary=output/'funcombat_server.rbxl'
    subprocess.run([str(Path(rbxmk).resolve()),'run','--allow-insecure-paths',str(converter),str(xml),str(binary)],check=True,capture_output=True,timeout=120)
    repair_place_services(binary,{item.get('class') for item in tree.findall('Item')})
    validate_saved_reference_types(binary)
    scalar_types=validate_saved_scalar_types(binary)
    decoded=Source(binary,rbxmk,cache/'roundtrip')
    # Validate independently decoded binary, including native property types.
    sp=decoded.tree.find('Item[@class="StarterPlayer"]')
    if sp.find('Item[@class="Model"]') is not None:
        raise ValueError('Saved custom player rig remains')
    if sp.findtext('Properties/bool[@name="LoadCharacterAppearance"]')!='true' or sp.findtext('Properties/token[@name="GameSettingsAvatar"]')!='0':
        raise ValueError('Native R6 appearance settings did not survive binary roundtrip')
    decoded_maps=[]
    decoded_data=next(x for x in decoded.tree.find('Item[@class="ServerStorage"]').findall('Item') if Source.name(x)==names['FunCombatData'])
    decoded_map_folder=next(x for x in decoded_data.findall('Item') if Source.name(x)==names['Maps'])
    decoded_maps=[x for x in decoded.tree.find('Item[@class="Workspace"]').findall('Item') if x.get('class')=='Model']+decoded_map_folder.findall('Item')
    if before_maps!=[map_digest(x) for x in decoded_maps]:
        raise ValueError('Binary roundtrip changed opaque map data')
    decoded_roots=set(decoded.tree.findall('Item'))
    for item in decoded.tree.iter('Item'):
        if item in decoded_roots or item.get('class') in required_classes or Source.name(item) in upstream_names:
            continue
        if not re.fullmatch('[0-9a-f]{12}',Source.name(item)):
            raise ValueError('Readable saved instance remains: '+Source.name(item))
    protocol.update({'buildId':build_id,'layoutVersion':6,'layout':'native blocky R6 players; two saved NPC templates; local readable names'})
    dump(repo/'config/protocol.json',protocol);dump(repo/'config/identifiers.json',identifiers)
    shutil.copy2(binary,repo/'server/funcombat_server.rbxl')
    report={'passed':True,'protocolVersion':5,'layoutVersion':6,'buildId':build_id,
        'baseServerSha256':source.sha,'serverSha256':sha(binary),'sourceAttachmentAvailable':(output/'Source/FunCombat_Original.rbxl').is_file(),
        'serverInstances':len(decoded.by),'mapEnvironmentModelsBefore':before_models-old_starters-len(previous_templates),
        'mapPayloadsUnchanged':True,'mapRoots':len(before_maps),'savedPlayerCharacterModels':0,
        'savedNpcTemplates':2,'renamableNamesOpaque':True,'runtimeObjectLabels':len(object_names),
        'serializedScalarPropertiesChecked':scalar_types['propertiesChecked'],
        'requiredEngineOrUpstreamNames':required,'robloxEngineTested':False,'multiplayerTested':False,
        'dynamicHeadRenderingTested':False,'geometryInspected':False}
    dump(output/'Native_R6_Checks.json',report)
    manifest=json.loads((repo/'manifest.json').read_text())
    manifest.update({'buildId':build_id,'layoutVersion':6,'buildStatus':'native blocky R6; offline checks; Roblox playtest required',
        'namesPreserved':'required engine containers and upstream Kohl configuration; external client restores other visible names'})
    manifest['files']=repository_files(repo);dump(repo/'manifest.json',manifest)
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True)
    parser.add_argument('--repo',default=str(base.ROOT))
    parser.add_argument('--output',required=True)
    parser.add_argument('--rbxmk',required=True)
    options=parser.parse_args()
    print(json.dumps(upgrade(options.source,options.repo,options.output,options.rbxmk),ensure_ascii=False,indent=2))
