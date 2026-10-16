from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/infer'
for f in up.iterdir():
 if f.is_file():shutil.copy(f,p/f.name)
source=(p/'Main.hs').read_text().replace('module Main where','module Kernel where',1);(p/'Kernel.hs').write_text(source)
(p/'Observer.hs').write_text('''module Main where
import Kernel
main = interact (\\input -> show testEnv ++ prompt ++ concatMap readInferShow (lines input))
''')
(p/'LineObserver.hs').write_text('''module Main where
import Kernel
main = interact (concatMap readInferShow . lines)
''')
for filename,exe in [('Main.hs','original'),('Observer.hs','observer'),('LineObserver.hs','line-observer')]:
 with(p/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,filename],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
records=[]
for profile,stem in [('smoke','fast'),('normal',''),('large','slow')]:
 stdin=p/('infer.'+stem+'stdin');expected=p/('infer.'+stem+'stdout');raw=subprocess.check_output([str(p/'original')],input=stdin.read_bytes(),timeout=600,preexec_fn=cap);assert raw==expected.read_bytes(),profile
 (p/(profile+'.stdout')).write_bytes(raw)
 text=subprocess.check_output([str(p/'observer')],input=stdin.read_bytes(),timeout=120,preexec_fn=cap);(p/(profile+'.text')).write_bytes(text)
 h=0
 for byte in text:h=(31*h+byte)&((1<<64)-1)
 signed=h if h<1<<63 else h-(1<<64);assert raw==(str(signed)+'\n').encode()*200
 records.append(dict(profile=profile,bytes=len(text),unsigned_hash=str(h),signed_hash=str(signed),repetitions=200));print('PASS original fixture, full text and independent hash',profile,len(text),signed,flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
