"""Offline Lua-subset syntax and behavior checks; this is NOT a Roblox engine."""
from pathlib import Path
import ctypes, ctypes.util, json, sys

ROOT=Path(__file__).resolve().parents[2]
libname=ctypes.util.find_library('lua5.4')
if not libname:raise SystemExit('Install liblua5.4 or use the documented Luau CLI test commands.')
lib=ctypes.CDLL(libname)
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.lua_close.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.luaL_loadstring.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype=ctypes.c_char_p

def lua_value(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,(int,float)):return repr(v)
    if isinstance(v,str):return json.dumps(v)
    if isinstance(v,list):return '{'+','.join(lua_value(x) for x in v)+'}'
    if isinstance(v,dict):return '{'+','.join('['+lua_value(k)+']='+lua_value(x) for k,x in v.items())+'}'
    raise TypeError(type(v))

def check(path,execute,setup=None):
    state=lib.luaL_newstate();lib.luaL_openlibs(state)
    try:
        status=0
        if setup:
            status=lib.luaL_loadstring(state,setup.encode())
            if not status:status=lib.lua_pcallk(state,0,0,0,0,None)
        if not status:status=lib.luaL_loadfilex(state,str(path).encode(),None)
        if not status and execute:status=lib.lua_pcallk(state,0,0,0,0,None)
        if status:raise RuntimeError((lib.lua_tolstring(state,-1,None) or b'Lua failed').decode())
    finally:lib.lua_close(state)

def main():
    import os
    os.chdir(ROOT)
    paths=sorted((ROOT/'portable').glob('*.lua'))
    for p in paths:check(p,False)
    for name in ('core.spec.lua','dance.spec.lua','dance_speed.spec.lua','dance_meter.spec.lua','dance_controller.spec.lua','dance_presentation.spec.lua','bus.spec.lua','runtime.spec.lua','fetch.spec.lua','controller.spec.lua','weapons.spec.lua','ui.spec.lua','gender.spec.lua','ragdoll.spec.lua','presentation.spec.lua','locomotion.spec.lua','emote_interaction.spec.lua','passive.spec.lua','dash.spec.lua','flight_probe.spec.lua','dash_effects.spec.lua','prompts.spec.lua'):
        p=ROOT/'portable/tests'/name
        setup=None
        if name=='prompts.spec.lua':setup='__TEST_PROMPT_DATA='+lua_value(json.loads((ROOT/'portable/prompt_templates.json').read_text()))
        check(p,True,setup)
    print(json.dumps({'syntaxFiles':len(paths),'runtime':'liblua5.4; Lua-subset checks only','robloxTested':False}))

if __name__=='__main__':main()
