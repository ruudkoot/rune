from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,dirs_exist_ok=True)
for filename in ['GamtebMain.hs','Pair.hs','Compton.hs']:
 f=d/filename;s=f.read_text()
 before={'GamtebMain.hs':'module GamtebMain (gamteb) where','Pair.hs':'module Pair (pair) where','Compton.hs':'module Compton (compton) where'}[filename]
 assert before in s
 f.write_text(s.replace(before,'module '+filename[:-3]+' where'))
(d/'Observer.hs').write_text('''module Main where
import GamtebMain
import InitTable
import Output
import Data.Array
import System.Environment
main=do
 [size,out]<-getArgs
 let n=read size
 let (results,stats)=sources 0.5 n 6
 let text=outGamteb n stats results
 if text/=gamteb n then error "observer differs" else return()
 writeFile(out++".text")text
 writeFile(out++".results")(unlines[unwords[show i,show j,show w]|((i,j),w)<-results])
 writeFile(out++".stats")(unlines[unwords[show i,show value]|(i,value)<-stats])
 putStrLn(unwords["particles",show n,"results",show(length results),"stats",show(length stats)])
''')
(d/'IsosProbe.hs').write_text('''module Main where
import Pair
import System.Environment
main=do
 [arg]<-getArgs
 print(isos(read arg))
''')
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for target,main in [('observer','Observer.hs'),('isos','IsosProbe.hs')]:
 with(d/(target+'-build.log')).open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o',target,main],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
metadata=[]
for n in [1,2,3,10,100,1000,5000]:
 r=subprocess.check_output([str(d/'observer'),str(n),str(p/str(n)),'+RTS','-M256m','-RTS'],cwd=d,timeout=60,preexec_fn=cap)
 (p/(str(n)+'.observe')).write_bytes(r);print(r.decode().strip(),flush=True)
for seed in ['0','0.1','0.25','0.5','0.75','0.9','0.999']:
 try:
  r=subprocess.run([str(d/'isos'),seed,'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=3,preexec_fn=cap)
  record=dict(seed=seed,exit=r.returncode,stdout=r.stdout.decode(),stderr=r.stderr.decode())
 except subprocess.TimeoutExpired:record=dict(seed=seed,status='timeout',seconds=3)
 metadata.append(record);print(record,flush=True)
(p/'isos-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
