"""Lossless source string recovery and typed presentation export for this place.

rbxmk performs the binary DOM conversion; we correct its XML 1.0-incompatible
binary string encoding before parsing. Unknown binary data is never silently
discarded from the source DOM. Runtime packages deliberately select writable
presentation properties while .rbxmx exports retain full source properties.
"""
from __future__ import annotations
import base64, collections, ctypes, ctypes.util, hashlib, json, math, re, shutil, struct, subprocess
from pathlib import Path
from lxml import etree as E

SCRIPT_CLASSES={'Script','LocalScript','ModuleScript'}
NETWORK_CLASSES={'RemoteEvent','RemoteFunction','BindableEvent','BindableFunction'}
BINARY_NAMES={'AttributesSerialize','Tags','CollisionGroupData','MaterialColors','SmoothGrid','PhysicsGrid','PhysicsData','ChildData','MeshData','GuidBinaryString','SerializedEmulatedPolicyInfo','HiddenServices','VisibleServices'}
SKIP_PROPERTIES={'UnscaledCofm','UnscaledVolInertiaDiags','UnscaledVolInertiaOffDiags','AttributesSerialize','Tags','Capabilities','DefinesCapabilities','UniqueId','HistoryId','SourceAssetId','Source','LinkedSource','ScriptGuid','Sandboxed','SecurityCapabilities','DefinesCapabilities','PhysicsData','ChildData','MeshData','InitialSize','MeshSize','PhysicalConfigData','PhysicsRepRootPart','NetworkIsSleeping','NetworkOwnershipRule','NetworkOwnerV3','ReceiveAge','AssemblyRootPart','AssemblyMass','AssemblyCenterOfMass','ModelMeshData','ModelMeshSize','ModelMeshCFrame','ModelMeshId','ModelMeshData','ModelInPrimary','WorldPivotData','PivotOffset','Color3uint8','SourceAssetId','AssetId','SerializedEmulatedPolicyInfo'}
ALIASES={'size':'Size','shape':'Shape','formFactorRaw':'FormFactor','Color3uint8':'Color','xmlRead_MaxDistance_3':'RollOffMaxDistance','xmlRead_MinDistance_3':'RollOffMinDistance'}

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def dump(path,value):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False),encoding='utf-8')

def repository_files(repo):
    repo=Path(repo)
    return {p.relative_to(repo).as_posix():{'sha256':sha(p),'bytes':p.stat().st_size}
            for p in sorted(repo.rglob('*')) if p.is_file() and p.name!='manifest.json'
            and not {'.git','__pycache__','.cache'}.intersection(p.relative_to(repo).parts)
            and p.suffix not in {'.pyc','.partial'}}

def normalize_xml(raw:bytes)->bytes:
    def fix(match):
        name,body=match.groups();nums=[int(x) for x in re.findall(rb'&#(\d+);',body)]
        if name.decode() not in BINARY_NAMES and not any(x<32 and x not in (9,10,13) for x in nums):return match[0]
        body=re.sub(rb'&#(\d+);',lambda z:bytes([int(z[1])]) if int(z[1])<256 else chr(int(z[1])).encode(),body)
        for old,new in [(b'&lt;',b'<'),(b'&gt;',b'>'),(b'&quot;',b'"'),(b'&apos;',b"'"),(b'&amp;',b'&')]:body=body.replace(old,new)
        return b'<BinaryString name="'+name+b'">'+base64.b64encode(body)+b'</BinaryString>'
    return re.sub(rb'<string name="([^"]+)">(.*?)</string>',fix,raw,flags=re.S)

class Reader:
    def __init__(self,b):self.b=b;self.p=0
    def read(self,n):
        out=self.b[self.p:self.p+n];self.p+=n
        if len(out)!=n:raise ValueError('Truncated binary chunk')
        return out
    def u32(self):return struct.unpack('<I',self.read(4))[0]
    def string(self):return self.read(self.u32())
    def refs(self,n):
        data=self.read(n*4);out=[];previous=0
        for i in range(n):
            v=int.from_bytes(bytes(data[j*n+i] for j in range(4)),'big');previous+=(v>>1)^-(v&1);out.append(previous)
        return out

def binary_chunks(path):
    data=Path(path).read_bytes()
    if data[:14]!=b'<roblox!\x89\xff\r\n\x1a\n':raise ValueError('Expected original binary Roblox place')
    chunks=[];p=32
    try:
        import lz4.block
        decompress=lambda b,n:lz4.block.decompress(b,uncompressed_size=n)
    except ImportError:
        libname=ctypes.util.find_library('lz4')
        if not libname:raise RuntimeError('Install required_dependencies.txt (lz4)')
        lib=ctypes.CDLL(libname)
        def decompress(b,n):
            out=ctypes.create_string_buffer(n)
            if lib.LZ4_decompress_safe(b,out,len(b),n)!=n:raise ValueError('Corrupt LZ4 source chunk')
            return out.raw
    while p<len(data):
        name,c,n,_=struct.unpack_from('<4sIII',data,p);p+=16;b=data[p:p+(c or n)];p+=c or n
        if c:
            if b[:4]==b'\x28\xb5\x2f\xfd':
                import zstandard
                b=zstandard.ZstdDecompressor().decompress(b,max_output_size=n)
            else:b=decompress(b,n)
        if len(b)!=n:raise ValueError('Binary chunk size mismatch')
        chunks.append((name,b))
    return chunks

def binary_property_schema(path):
    """Read property type IDs directly, independently of ambiguous XML tags."""
    chunks=binary_chunks(path);classes={};schema={}
    for name,body in chunks:
        if name==b'INST':
            r=Reader(body);cid=r.u32();classes[cid]=r.string().decode()
    for name,body in chunks:
        if name==b'PROP':
            r=Reader(body);cid=r.u32();pn=r.string().decode();typ=r.read(1)[0]
            key=(classes[cid],pn)
            if key in schema and schema[key]!=typ:raise ValueError('Conflicting binary property types: '+'.'.join(key))
            schema[key]=typ
    return schema

def source_strings(path):
    chunks=[(name,Reader(body)) for name,body in binary_chunks(path)]
    classes={};nodes={};property_types={}
    for name,r in chunks:
        if name==b'INST':
            cid=r.u32();cn=r.string().decode();r.read(1);n=r.u32();refs=r.refs(n);classes[cid]=(cn,refs)
            types={}
            property_types[cid]=types
            for i in refs:nodes[i]={'id':i,'class':cn,'parent':-1,'props':{},'types':types}
    for name,r in chunks:
        if name==b'PROP':
            cid=r.u32();pn=r.string().decode();typ=r.read(1)[0]
            property_types[cid][pn]=typ
            if typ==1:
                for ref in classes[cid][1]:nodes[ref]['props'][pn]=r.string()
        elif name==b'PRNT':
            r.read(1);n=r.u32();children=r.refs(n);parents=r.refs(n)
            for a,b in zip(children,parents):nodes[a]['parent']=b
    return nodes

class Source:
    def __init__(self,binary,rbxmk,cache):
        self.input=Path(binary).resolve();self.sha=sha(self.input);cache=Path(cache);cache.mkdir(parents=True,exist_ok=True)
        converted=cache/(self.sha+'.rbxlx')
        valid_cache=False
        if converted.exists():
            with converted.open('rb') as check:
                check.seek(max(0,converted.stat().st_size-128));valid_cache=b'</roblox>' in check.read()
        if not valid_cache:
            converter=cache/'convert.lua';converter.write_text("local a,b=...\nfs.write(b,fs.read(a,'rbxl'),'rbxlx')\n")
            temporary=converted.with_suffix('.partial.rbxlx')
            executable=str(Path(shutil.which(str(rbxmk)) or rbxmk).resolve())
            subprocess.run([executable,'run','--allow-insecure-paths',str(converter.resolve()),str(self.input),str(temporary.resolve())],check=True)
            if not temporary.exists() or b'</roblox>' not in temporary.read_bytes()[-128:]:
                raise RuntimeError('rbxmk did not produce a complete XML document; original was not changed')
            temporary.replace(converted)
        self.basic=source_strings(self.input);self.tree=E.fromstring(normalize_xml(converted.read_bytes()))
        elements=list(self.tree.iter('Item'))
        # Studio's source referents are a depth-first ordinal for this file.
        # Reject another layout instead of silently assigning wrong identities.
        self.by={};self.paths={};self.reverse={}
        for i,e in enumerate(elements):
            src=self.basic.get(i)
            if src is None or src['class']!=e.get('class'):raise ValueError('Unexpected source referent order: game-specific conversion required')
            for prop in e.findall('Properties/*'):
                key=prop.get('name')
                # Roblox XML writes BrickColor as <int>. Without a descriptor,
                # that ambiguous tag becomes Int32 on re-encoding. Preserve the
                # original binary type using the explicit XML spelling instead.
                if src['types'].get(key)==0x0B and prop.tag=='int':prop.tag='BrickColor'
                if prop.tag!='string':continue
                raw=src['props'].get(key)
                if raw is not None:
                    if key in BINARY_NAMES:
                        prop.tag='BinaryString';prop.text=base64.b64encode(raw).decode()
                    else:
                        try:prop.text=raw.decode('utf-8')
                        except (UnicodeDecodeError,ValueError):prop.tag='BinaryString';prop.text=base64.b64encode(raw).decode()
            self.by[i]=e;self.reverse[e.get('referent')]=i
            self.paths[i]=self.paths.get(src['parent'],'')+'/'+self.name(e)
        if len(self.by)!=len(self.basic):raise ValueError('Decoder lost source instances')
    @staticmethod
    def name(e):return e.findtext('Properties/string[@name="Name"]') or e.get('class')
    def descendants(self,i):return [i]+[self.reverse[e.get('referent')] for e in self.by[i].iterdescendants('Item')]
    def child(self,i,name):
        for e in self.by[i].findall('Item'):
            if self.name(e)==name:return self.reverse[e.get('referent')]
        return None

def numbers(p):return [float(v) for v in (p.text or '').split()]
def ordered(p,keys):return [float(p.findtext(k,'0')) for k in keys]

def typed_property(p,refs=None):
    name=ALIASES.get(p.get('name'),p.get('name'));t=p.tag;text=p.text or '';refs=refs or {}
    if t in {'float','double'}:v=float(text or 0);v=0 if not math.isfinite(v) else v;t='number'
    elif t in {'int','int64','token','BrickColor'}:v=int(text or 0)
    elif t=='bool':v=text=='true'
    elif t in {'string','ProtectedString','Content'}:v=p.findtext('url','') if t=='Content' else text;t='string'
    elif t=='Ref':v=refs.get(text)
    elif t=='Color3uint8':
        n=int(text);v=[((n>>16)&255)/255,((n>>8)&255)/255,(n&255)/255];t='Color3'
    elif t=='Color3':v=ordered(p,['R','G','B'])
    elif t in {'Vector3','Vector3int16'}:v=ordered(p,['X','Y','Z'])
    elif t=='Vector2':v=ordered(p,['X','Y'])
    elif t in {'CoordinateFrame','CFrame'}:v=ordered(p,['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22']);t='CFrame'
    elif t=='UDim':v=ordered(p,['S','O'])
    elif t=='UDim2':v=ordered(p,['XS','XO','YS','YO'])
    elif t=='NumberRange':v=numbers(p)
    elif t in {'NumberSequence','ColorSequence'}:
        ns=numbers(p);step=3 if t=='NumberSequence' else 5;v=[ns[i:i+step] for i in range(0,len(ns),step)]
    elif t in {'Rect','Rect2D'}:
        v=ordered(p,['min/X','min/Y','max/X','max/Y']);t='Rect'
    elif t=='PhysicalProperties':
        v=None if p.findtext('CustomPhysics')=='false' else ordered(p,['Density','Friction','Elasticity','FrictionWeight','ElasticityWeight'])
    elif t=='Font':
        v={'family':p.findtext('Family/url',''),'weight':int(p.findtext('Weight','400')),'style':p.findtext('Style','Normal')}
    elif t in {'Faces','Axes'}:v=int(p.findtext(t.lower(),text) or 0)
    elif t in {'BinaryString','SharedString','UniqueId','SecurityCapabilities','OptionalCoordinateFrame'}:return None
    else:raise ValueError('Unhandled property type '+t+' '+name)
    return name,{'type':t,'value':v}

def decode_attributes(b64):
    """Source has float/string/bool attributes. Fail closed for unknown kinds."""
    if not b64:return {}
    data=base64.b64decode(b64);r=Reader(data);out={}
    if not data:return out
    for _ in range(r.u32()):
        key=r.string().decode('utf8');t=r.read(1)[0]
        if t==2:v=r.string().decode('utf8')
        elif t==3:v=bool(r.read(1)[0])
        elif t==6:v=struct.unpack('<d',r.read(8))[0]
        elif t==5:v=struct.unpack('<f',r.read(4))[0]
        else:raise ValueError('Unsupported attribute type %s for %s'%(t,key))
        out[key]=v
    return out

def package(source,root_id,excluded=(),exclude_tools=False):
    banned=set(excluded);nodes=[];external=[];included=[]
    def visit(e,parent=None):
        i=source.reverse[e.get('referent')];cls=e.get('class')
        if i in banned or cls in SCRIPT_CLASSES|NETWORK_CLASSES or (exclude_tools and cls=='Tool'):return
        props={};attrs={}
        for p in e.find('Properties'):
            pn=p.get('name')
            if pn=='AttributesSerialize':attrs=decode_attributes(p.text);continue
            if pn in SKIP_PROPERTIES and pn!='Color3uint8':continue
            prop=typed_property(p,source.reverse)
            if prop:props[prop[0]]=prop[1]
        node={'id':i,'class':cls,'name':source.name(e),'parent':parent,'properties':props,'attributes':attrs}
        bounds=e.find('Properties/Vector3[@name="InitialSize"]')
        if cls=='MeshPart' and bounds is not None:node['meshSize']=ordered(bounds,['X','Y','Z'])
        nodes.append(node);included.append(i)
        for child in e.findall('Item'):visit(child,i)
    visit(source.by[root_id]);ids=set(included)
    for n in nodes:
        for key,val in n['properties'].items():
            if val['type']=='Ref' and val['value'] is not None and val['value'] not in ids:
                external.append({'source':n['id'],'property':key,'target':val['value']});val['value']=None
    return {'version':1,'root':root_id,'nodes':nodes,'externalReferences':external}

def animation(source,i):
    e=source.by[i];frames=[]
    for k in e.findall('Item[@class="Keyframe"]'):
        t=float(k.findtext('Properties/float[@name="Time"]','0'));poses=[]
        def visit(p,parent=None):
            props=p.find('Properties');cf=props.find('CoordinateFrame[@name="CFrame"]')
            poses.append({'name':source.name(p),'parent':parent,'cframe':typed_property(cf)[1]['value'],'weight':float(props.findtext('float[@name="Weight"]','1')),'easingStyle':int(props.findtext('token[@name="EasingStyle"]','0')),'easingDirection':int(props.findtext('token[@name="EasingDirection"]','0'))})
            for child in p.findall('Item[@class="Pose"]'):visit(child,source.name(p))
        for p in k.findall('Item[@class="Pose"]'):visit(p)
        frames.append({'time':t,'poses':poses})
    frames.sort(key=lambda x:x['time'])
    return {'version':1,'name':source.name(e),'sourceId':i,'loop':e.findtext('Properties/bool[@name="Loop"]')=='true','priority':int(e.findtext('Properties/token[@name="Priority"]','2')),'duration':frames[-1]['time'] if frames else 0,'frames':frames}
