"""Reexport only native combat ProximityPrompt definitions from binary RBXL.

Other instance properties and geometry payloads are skipped, not interpreted.
The input is never written. No scripts, meshes, animation poses or geometry properties are decoded.
"""
from pathlib import Path
import ctypes,ctypes.util,struct,json,hashlib,sys

class Reader:
    def __init__(self,b):self.b=b;self.at=0
    def take(self,n):
        data=self.b[self.at:self.at+n];self.at+=n
        if len(data)!=n:raise ValueError('Truncated chunk')
        return data
    def u32(self):return struct.unpack('<I',self.take(4))[0]
    def text(self):return self.take(self.u32()).decode('utf-8')
    def interleaved(self,n):
        data=self.take(n*4)
        return [int.from_bytes(bytes(data[j*n+i]for j in range(4)),'big')for i in range(n)]
    def refs(self,n):
        refs=[];last=0
        for v in self.interleaved(n):last+=(v>>1)^-(v&1);refs.append(last)
        return refs
    def floats(self,n):
        return [struct.unpack('>f',struct.pack('>I',(v>>1)|((v&1)<<31)))[0]for v in self.interleaved(n)]

def chunks(data):
    assert data[:14]==b'<roblox!\x89\xff\r\n\x1a\n','Not binary RBXL'
    try:
        import lz4.block
        unpack=lambda body,n:lz4.block.decompress(body,uncompressed_size=n)
    except ImportError:
        libname=ctypes.util.find_library('lz4')
        if not libname:raise RuntimeError('Install lz4 or provide liblz4')
        lib=ctypes.CDLL(libname)
        lib.LZ4_decompress_safe.argtypes=[ctypes.c_char_p,ctypes.c_void_p,ctypes.c_int,ctypes.c_int]
        lib.LZ4_decompress_safe.restype=ctypes.c_int
        def unpack(body,n):
            out=ctypes.create_string_buffer(n)
            assert lib.LZ4_decompress_safe(body,out,len(body),n)==n,'Bad LZ4 chunk'
            return out.raw
    at=32
    while at<len(data):
        name,packed,length,reserved=struct.unpack_from('<4sIII',data,at);at+=16
        body=data[at:at+(packed or length)];at+=packed or length
        if packed:
            if body[:4]==b'\x28\xb5\x2f\xfd':
                import zstandard
                body=zstandard.ZstdDecompressor().decompress(body,max_output_size=length)
            else:
                body=unpack(body,length)
        assert len(body)==length
        yield name,body

def export(path):
    p=Path(path);raw=p.read_bytes();chunklist=list(chunks(raw));classes={};nodes={}
    for name,body in chunklist:
        if name==b'INST':
            r=Reader(body);cid=r.u32();cls=r.text();r.take(1);refs=r.refs(r.u32());classes[cid]=(cls,refs)
            for ref in refs:nodes[ref]={'id':ref,'class':cls,'name':'','parent':-1,'props':{}}
    for name,body in chunklist:
        if name==b'PRNT':
            r=Reader(body);r.take(1);n=r.u32();children=r.refs(n);parents=r.refs(n)
            for ref,parent in zip(children,parents):nodes[ref]['parent']=parent
        elif name==b'PROP':
            r=Reader(body);cid=r.u32();prop=r.text();kind=r.take(1)[0];cls,refs=classes[cid];n=len(refs)
            if prop=='Name'and kind==1:
                for ref in refs:nodes[ref]['name']=r.text()
                continue
            if cls!='ProximityPrompt':continue
            if prop not in FIELDS:continue
            if kind==1:values=[r.text()for _ in refs]
            elif kind==2:values=[bool(v)for v in r.take(n)]
            elif kind==4:values=r.floats(n)
            elif kind==13:
                x,y=r.floats(n),r.floats(n);values=[{'x':a,'y':b}for a,b in zip(x,y)]
            elif kind==18:values=r.interleaved(n)
            else:raise ValueError('Unsupported prompt property type: '+prop)
            for ref,value in zip(refs,values):nodes[ref]['props'][prop]=value
    def path_of(ref):
        parts=[];visited=set()
        while ref in nodes and ref not in visited:
            visited.add(ref);node=nodes[ref];parts.append(node['name']);ref=node['parent']
        return '.'.join(reversed(parts))
    templates={}
    for name in NAMES:
        candidates=[n for n in nodes.values()if n['class']=='ProximityPrompt'and path_of(n['id'])=='ReplicatedStorage.Prompts.'+name]
        assert len(candidates)==1,'Expected one original template: '+name
        node=candidates[0];props={key:node['props'][key]for key in FIELDS};props['Name']=name
        for key,mapping in ENUMS.items():props[key]=mapping[props[key]]
        templates[name]={'sourceId':node['id'],'sourcePath':path_of(node['id']),'properties':props}
    assert hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256(raw).digest(),'Input changed during export'
    return {'version':1,'sourceName':p.name,'sourceSha256':hashlib.sha256(raw).hexdigest(),'parentPart':'Torso',
        'downed':['executePrompt','carryPrompt','DefaultFun'],'templates':templates,'pairedModeImplemented':False}

NAMES=('executePrompt','carryPrompt','DefaultFun','dropPrompt','finishHoldPrompt','stopPrompt')
FIELDS=('ActionText','ObjectText','AutoLocalize','ClickablePrompt','RequiresLineOfSight','Enabled','HoldDuration','MaxActivationDistance','KeyboardKeyCode','GamepadKeyCode','Exclusivity','Style','UIOffset')
ENUMS={'KeyboardKeyCode':{101:'E',116:'T',114:'R'},'GamepadKeyCode':{1000:'ButtonX'},'Exclusivity':{0:'OnePerButton'},'Style':{0:'Default'}}

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source');parser.add_argument('--output',default=str(Path(__file__).with_name('prompt_templates.json')))
    args=parser.parse_args();source=Path(args.source).resolve();out=Path(args.output).resolve()
    if source==out or (out.exists()and out.samefile(source)):raise SystemExit('Output must not overwrite the source place')
    profile=export(source);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(profile,separators=(',',':'))+'\n')
    print(json.dumps({'sourceSha256':profile['sourceSha256'],'templates':len(profile['templates']),'output':str(out)}))
