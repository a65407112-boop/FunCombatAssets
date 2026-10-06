"""Execute the builder's native Kohl settings using the original settings source."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from lxml import etree as E

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'Builder'))
from build import add_kohl_admin, read_admin_settings

parser=argparse.ArgumentParser()
parser.add_argument('--luau',required=True)
args=parser.parse_args()
owner=read_admin_settings(ROOT)['ownerUserId']

def configured(source):
    original=E.fromstring(b'<Item class="Script" referent="Credit"><Properties><string name="Name">Credit</string></Properties><Item class="ModuleScript" referent="Settings"><Properties><string name="Name">Settings</string></Properties></Item><Item class="ModuleScript" referent="Custom"><Properties><string name="Name">Custom Commands</string><ProtectedString name="Source">return {}</ProtectedString></Properties></Item></Item>')
    E.SubElement(original.find('Item/Properties'),'ProtectedString',name='Source').text=source
    before=E.tostring(original)
    service=E.fromstring(b'<Item class="ServerScriptService"><Properties/></Item>')
    generated=add_kohl_admin(SimpleNamespace(by={6657:original}),service,owner)
    assert E.tostring(original)==before,'Native settings migration modified the input DOM'
    settings=next(e for e in generated.findall('Item') if e.findtext('Properties/string[@name="Name"]')=='Settings')
    return settings.findtext('Properties/*[@name="Source"]')

original=(ROOT/'source/scripts/6658.lua').read_text()
code='local Color3={new=function(r,g,b) return {r,g,b} end}\n'
code+='local expected=(function()\n'+original+'\nend)()\n'
code+='local actual=(function()\n'+configured(original)+'\nend)()\n'
code+=r'''
local function equal(a,b)
    assert(type(a)==type(b),'An original settings type changed')
    if type(a)~='table' then assert(a==b,'An original setting changed');return end
    for k,v in pairs(a) do equal(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'An original setting was invented') end
end
equal(expected[1],actual[1])
for i=2,6 do equal(expected[2][i],actual[2][i]) end
assert(#expected[2][1]==0 and #actual[2][1]==1 and actual[2][1][1]==11556197791,'The declared account did not receive native Owners membership')
assert(actual[1].Prefix==':' and actual[1].FreeAdmin==false,'Native public/admin settings changed')
print('Kohl settings: original settings and other role lists preserved')
'''
for label,owners,expected in [
    ('existing numeric owner is not duplicated','{11556197791,"OtherOwner",17}','{11556197791,"OtherOwner",17}'),
    ('other existing owners remain present','{"OtherOwner",17}','{"OtherOwner",17,11556197791}')]:
    fixture='return {{Prefix=":"}, {'+owners+', {}, {}, {}, {}, {}}}'
    code+='\ndo\nlocal actual=(function()\n'+configured(fixture)+'\nend)()\nequal(actual[2][1],'+expected+')\nprint('+repr('Kohl settings: '+label)+')\nend\n'
code+='print("Kohl settings scenarios passed: 3")\n'
with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
    path=Path(temporary)/'native-settings.luau';path.write_text(code)
    subprocess.run([str(Path(args.luau).resolve()),str(path)],check=True)
