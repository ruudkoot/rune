from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel';shutil.copy(up/'Fast2haskell.hs',p/'Fast2haskell.hs');rows=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
for name in ['listcompr','listcopy']:
 d=p/name;d.mkdir(exist_ok=True)
 for f in(up/name).iterdir():
  if f.is_file():shutil.copy(f,d/f.name)
 with(d/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
 text=(d/'Main.hs').read_text().replace('module Main (main)','module Kernel',1);(d/'Kernel.hs').write_text(text)
 (d/'Observer.hs').write_text('''module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 putStr(f_main(read arg))
''')
 with(d/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
 for profile,n,fixture in [('smoke',2000,name+'.faststdout'),('normal',20000,name+'.stdout'),('large',100000,name+'.slowstdout')]:
  output=subprocess.check_output([str(d/'original'),str(n)],cwd=d,timeout=180,preexec_fn=cap);assert output==(d/fixture).read_bytes();(d/(profile+'.stdout')).write_bytes(output);rows.append(dict(benchmark=name,profile=profile,n=n,length=int(output)));print('PASS unmodified original',name,profile,n,int(output),flush=True)
 for n in [0,1,2]:
  raw=subprocess.check_output([str(d/'observer'),str(n)],cwd=d,timeout=30,preexec_fn=cap);(d/(str(n)+'.program')).write_bytes(raw);print('Recorded complete transformed program',name,n,len(raw),flush=True)
(p/'metadata.json').write_text(json.dumps(rows,indent=2)+'\n')
