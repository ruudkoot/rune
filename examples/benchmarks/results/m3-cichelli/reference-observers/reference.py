from pathlib import Path
import shutil,subprocess,resource,json,ast
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/cichelli'
for f in up.iterdir():
 if f.is_file():shutil.copy(f,p/f.name)
source=(p/'Prog.hs').read_text().replace('module Prog(prog) where','module RichProg where',1);(p/'RichProg.hs').write_text(source)
(p/'Observer.hs').write_text('''module Main where
import RichProg
import Auxil
import qualified Key
main=do
 print Key.keys
 print freqtab
 print maxval
 print [(s,a,z,n) | K s a z n <- blocked (attribkeys Key.keys)]
 mapM_ (\\n->putStrLn(prog n)) [1,2]
 mapM_ (\\n->putStrLn(show n ++ ":" ++ show(findhash(blocked(attribkeys(take n Key.keys)))))) [0,1,2,5,10,15,22]
''')
for filename,exe in [('Main.hs','original'),('Observer.hs','observer')]:
 with(p/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,filename],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
for profile,n,fixture in [('smoke',6,'cichelli.faststdout'),('normal',60,'cichelli.stdout'),('large',300,'cichelli.slowstdout')]:
 raw=subprocess.check_output([str(p/'original'),str(n)],timeout=180,preexec_fn=cap);assert raw==(p/fixture).read_bytes(),profile;(p/(profile+'.output')).write_bytes(raw);print('PASS complete original',profile,n,len(raw),flush=True)
raw=subprocess.check_output([str(p/'observer')],timeout=180,preexec_fn=cap);(p/'observer.output').write_bytes(raw);lines=raw.decode().splitlines();keys=ast.literal_eval(lines[0]);frequency=ast.literal_eval(lines[1]);maximum=int(lines[2]);blocked=ast.literal_eval(lines[3])
(p/'data.json').write_text(json.dumps(dict(keys=keys,frequency=frequency,maximum=maximum,blocked=blocked,odd=lines[4],even=lines[5],prefixes=lines[6:]),indent=2)+'\n')
print('PASS original data/parity/prefix observers',flush=True)
