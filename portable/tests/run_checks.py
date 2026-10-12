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
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype=ctypes.c_char_p

def check(path,execute):
    state=lib.luaL_newstate();lib.luaL_openlibs(state)
    try:
        status=lib.luaL_loadfilex(state,str(path).encode(),None)
        if not status and execute:status=lib.lua_pcallk(state,0,0,0,0,None)
        if status:raise RuntimeError((lib.lua_tolstring(state,-1,None) or b'Lua failed').decode())
    finally:lib.lua_close(state)

def main():
    import os
    os.chdir(ROOT)
    paths=sorted((ROOT/'portable').glob('*.lua'))
    for p in paths:check(p,False)
    for name in ('core.spec.lua','bus.spec.lua','runtime.spec.lua','fetch.spec.lua','controller.spec.lua','collision.spec.lua'):
        p=ROOT/'portable/tests'/name
        if p.exists():check(p,True)
    print(json.dumps({'syntaxFiles':len(paths),'runtime':'liblua5.4; Lua-subset checks only','robloxTested':False}))

if __name__=='__main__':main()
