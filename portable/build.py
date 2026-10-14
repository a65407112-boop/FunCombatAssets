"""Rebuild the single loader and integrity manifest without original place bytes."""
from pathlib import Path
import hashlib,json,zlib

ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'portable'
SHARED='72d4e7ffd5cde727b8b6f0180186e8a891278bed'
def metadata(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'adler32':zlib.adler32(raw)&0xffffffff}
def main():
    fetch=(DIR/'fetch.lua').read_text()
    template=(DIR/'loader.template.lua').read_text()
    assert template.count('--@FETCH_MODULE@')==1
    (DIR/'loader.lua').write_text(template.replace('--@FETCH_MODULE@',fetch))
    diagnostic=(DIR/'diagnose_flight.template.lua').read_text()
    assert diagnostic.count('--@FLIGHT_PROBE_MODULE@')==1
    (DIR/'diagnose_flight.lua').write_text(diagnostic.replace('--@FLIGHT_PROBE_MODULE@',(DIR/'flight_probe.lua').read_text()))
    modules=['core','bus','visibility','appearance','passive','ragdoll','prompts','avatars','weapons','locomotion','dash_effects','dash','controller','dance_meter','ui']
    paths=sorted(p for p in DIR.rglob('*') if p.is_file() and p.name not in ('manifest.json',) and '__pycache__' not in p.parts)
    files={p.relative_to(ROOT).as_posix():metadata(p.read_bytes()) for p in paths}
    code_bytes=b''.join((DIR/(m+'.lua')).read_bytes() for m in modules)+(DIR/'loader.lua').read_bytes()+(DIR/'config.json').read_bytes()+(DIR/'prompt_templates.json').read_bytes()
    build='portable-'+hashlib.sha256(code_bytes).hexdigest()[:24]
    shared_source=json.loads((DIR/'shared_source.json').read_text())
    assert shared_source['commit']==SHARED
    manifest={'version':2,'mode':'local-only','executeButton':False,'glory':'combat-finisher','buildId':build,'sharedCommit':SHARED,'sharedManifest':shared_source['manifest'],
        'modules':modules,'sharedModules':['cleanup','assets','animations','audio'],
        'presentation':'original-gui','physics':'anchored-visuals','nativePromptUI':'three-source-profiles','pairedModeImplemented':False,
        'danceActionImplemented':True,'danceAnimation':'Emotes/Boston Breakdance','dancePlayback':'meter-controlled-local-adaptation','danceMeterImplemented':True,
        'preloadAnimations':['bat/swing_1','bat/swing_2','bat/swing_3','bat/flourish','other/carryGrabber','other/carryGrabbed','bat/gripAttacker','bat/gripVictim','bat/finishHoldAttacker','bat/finishHoldVictim','Emotes/Boston Breakdance','Emotes/Flex','Emotes/Rat','Emotes/Akiyama','Emotes/idk'],'files':files,'robloxTested':False}
    (DIR/'manifest.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    print(json.dumps({'buildId':build,'files':len(files),'loaderBytes':(DIR/'loader.lua').stat().st_size}))
if __name__=='__main__':main()
