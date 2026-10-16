from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/scs'
for f in up.iterdir():
 if f.is_file():shutil.copy(f,p/f.name)
shutil.copytree(up/'runtime_files',p/'runtime_files',dirs_exist_ok=True)
source=(p/'Main.hs').read_text().replace('module Main(main) where','module Kernel where',1);(p/'Kernel.hs').write_text(source)
(p/'Observer.hs').write_text('''module Main where
import Kernel
import System.Environment
main=do
 [file,seed,dt,end,temp,rbc]<-getArgs
 scs file (read seed) (head (Parse.parse_exact dt)) (head (Parse.parse_exact end)) (head (Parse.parse_approx temp)) (head (Parse.parse_approx rbc))
'''.replace('import System.Environment','import System.Environment\nimport qualified Parse'))
for filename,exe in [('Main.hs','original'),('Observer.hs','observer')]:
 with(p/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,filename],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
rows=[]
for profile,dt,end in [('smoke','10n','2u'),('normal','2n','4u'),('large','400p','4u')]:
 args=['runtime_files/inverter','345',dt,end,'1'];output=subprocess.check_output([str(p/'original'),*args],cwd=p,timeout=600,preexec_fn=cap);assert output==(p/'scs.stdout').read_bytes();(p/(profile+'.stdout')).write_bytes(output)
 raw=subprocess.check_output([str(p/'observer'),*args,'0'],cwd=p,timeout=600,preexec_fn=cap);(p/(profile+'.trace')).write_bytes(raw)
 rows.append(dict(profile=profile,args=args+['0'],bytes=len(raw),rows=len(raw.splitlines())-1));print('PASS unmodified source fixture and full trace',profile,len(raw),len(raw.splitlines())-1,flush=True)
(p/'metadata.json').write_text(json.dumps(rows,indent=2)+'\n')
