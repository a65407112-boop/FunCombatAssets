"""Optional source-byte regression; pass the original RBXL explicitly."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,tempfile

ROOT=Path(__file__).resolve().parents[2]
source=Path(sys.argv[1]).resolve();before=hashlib.sha256(source.read_bytes()).digest()
with tempfile.TemporaryDirectory(dir=ROOT) as folder:
    copy=Path(folder)/source.name;shutil.copyfile(source,copy)
    alias=Path(folder)/'alias.rbxl';os.link(copy,alias)
    result=subprocess.run([sys.executable,str(ROOT/'portable/export_prompts.py'),str(copy),'--output',str(alias)],capture_output=True,text=True)
    assert result.returncode!=0 and hashlib.sha256(copy.read_bytes()).digest()==before,'Exporter must refuse output hard links without modifying the input'
    output=Path(folder)/'prompt_templates.json'
    subprocess.run([sys.executable,str(ROOT/'portable/export_prompts.py'),str(copy),'--output',str(output)],check=True,capture_output=True)
    assert output.read_bytes()==(ROOT/'portable/prompt_templates.json').read_bytes(),'Original prompt definitions must reexport byte-for-byte'
assert hashlib.sha256(source.read_bytes()).digest()==before,'Original source must remain unchanged'
print(json.dumps({'hardLinkOutputRefused':True,'reexportIdentical':True,'originalInputUnchanged':True,'robloxTested':False}))
