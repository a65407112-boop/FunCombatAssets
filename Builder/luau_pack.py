"""Reversible literal pooling and conservative token spacing; no VM/loadstring."""
import hashlib, json, re

def tokens(source):
    result=[];i=0
    while i<len(source):
        if source[i].isspace():i+=1;continue
        comment=source.startswith('--',i)
        start=i+2 if comment else i
        long=re.match(r'\[(=*)\[',source[start:])
        if long:
            close=']'+long[1]+']';end=source.find(close,start+len(long[0]))
            if end<0:raise ValueError('Unterminated long string/comment')
            if not comment:result.append(('string',source[i:end+len(close)]))
            i=end+len(close);continue
        if comment:
            end=source.find('\n',i);i=len(source) if end<0 else end+1;continue
        if source[i] in "\"'":
            quote=source[i];end=i+1
            while end<len(source):
                if source[end]=='\\':end+=2
                elif source[end]==quote:break
                else:end+=1
            if end>=len(source):raise ValueError('Unterminated quoted string')
            result.append(('string',source[i:end+1]));i=end+1;continue
        match=re.match(r'[A-Za-z_][A-Za-z_0-9]*|0[xX][0-9A-Fa-f]+(?:\.(?!\.)[0-9A-Fa-f]*)?(?:[pP][+-]?\d+)?|\d+(?:\.(?!\.)\d*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?|\.\.\.|\.\.=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|//=|//|%=|\^=|::|->|.',source[i:],re.S)
        value=match[0];result.append(('code',value));i+=len(value)
    return result

def normalize_tokens(parts):
    # Lua permits f "argument" and f [[argument]]. A pooled expression needs
    # parentheses in that position; normalize both input and decoded output.
    keywords={'and','or','not','return','then','else','elseif','do','end','function','local','while','for','repeat','until','if','in','break','continue','true','false','nil'}
    out=[]
    for kind,value in parts:
        previous=out[-1][1] if out else ''
        sugar=kind=='string' and (previous in {')',']'} or (re.fullmatch('[A-Za-z_][A-Za-z_0-9]*',previous) and previous not in keywords))
        if sugar:out.extend([('code','('),(kind,value),('code',')')])
        else:out.append((kind,value))
    return out

def string_bytes(literal):
    long=re.match(r'\[(=*)\[',literal)
    if long:
        value=literal[len(long[0]):-len(long[1])-2].replace('\r\n','\n').replace('\r','\n')
        if value.startswith('\n'):value=value[1:]
        return value.encode('utf8')
    source=literal[1:-1];out=bytearray();i=0
    escapes={'a':7,'b':8,'f':12,'n':10,'r':13,'t':9,'v':11,'\\':92,'"':34,"'":39}
    while i<len(source):
        if source[i]!='\\':out.extend(source[i].encode('utf8'));i+=1;continue
        i+=1
        if i>=len(source):raise ValueError('Truncated escape')
        c=source[i]
        if c in escapes:out.append(escapes[c]);i+=1
        elif c.isdigit():
            m=re.match(r'\d{1,3}',source[i:]);n=int(m[0])
            if n>255:raise ValueError('Out-of-range decimal escape')
            out.append(n);i+=len(m[0])
        elif c=='x':out.append(int(source[i+1:i+3],16));i+=3
        elif c=='u':
            m=re.match(r'u\{([0-9a-fA-F]+)\}',source[i:])
            if not m:raise ValueError('Invalid Unicode escape')
            out.extend(chr(int(m[1],16)).encode('utf8'));i+=len(m[0])
        elif c=='z':
            i+=1
            while i<len(source) and source[i].isspace():i+=1
        elif c in '\r\n':
            if c=='\r' and source[i+1:i+2]=='\n':i+=1
            out.append(10);i+=1
        else:raise ValueError('Unsupported Lua escape '+c)
    return bytes(out)

def quote_bytes(value):
    return '"'+''.join(chr(v) if 32<=v<=126 and v not in (34,92) else '\\%03d'%v for v in value)+'"'

def pack(source):
    name='__v_'+hashlib.sha256(source.encode()).hexdigest()[:8]
    if name in source:raise ValueError('Literal-pool name collision')
    salt=73;pool=[];index={};body=[]
    for kind,value in normalize_tokens(tokens(source)):
        if kind=='string':
            value=string_bytes(value)
            if value not in index:index[value]=len(pool)+1;pool.append([(b+salt)%256 for b in value])
            body.append(name+'['+str(index[value])+']')
        else:body.append(value)
    if not pool:return ' '.join(body)
    encoded=json.dumps(pool,separators=(',',':')).replace('[','{').replace(']','}')
    prefix='local '+name+'=(function()local p='+encoded+' local r={}for i,a in ipairs(p)do local b={}for j,x in ipairs(a)do b[j]=string.char((x-'+str(salt)+')%256)end r[i]=table.concat(b)end return r end)();'
    return prefix+' '.join(body)

def restore(source):
    match=re.match(r'local (__v_[0-9a-f]+)=\(function\(\)local p=(.*?) local r=\{\}.*?\(x-(\d+)\)%256.*?end\)\(\);',source,re.S)
    if not match:return source
    pool=json.loads(match[2].replace('{','[').replace('}',']'));salt=int(match[3])
    values=[bytes((n-salt)%256 for n in item) for item in pool]
    return re.sub(re.escape(match[1])+r'\[(\d+)\]',lambda m:quote_bytes(values[int(m[1])-1]),source[match.end():])
