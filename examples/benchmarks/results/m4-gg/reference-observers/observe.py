from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,dirs_exist_ok=True)
s=(d/'Main.hs').read_text().replace('module Main where','module Program where')
(d/'Program.hs').write_text(s)
for name in ['Activity','Spark','Pool']:
 f=d/(name+'.hs');s=f.read_text();a=s.index('module ');b=s.index('where',a)+5
 s=s[:a]+'module '+name+' where'+s[b:];f.write_text(s)
(d/'Observer.hs').write_text('''module Main where
import qualified Program as P
import qualified Activity as A
import qualified Spark as S
import qualified Pool as O
import GRIP
import Parse
import Graph
import NofibUtils
import System.Environment
main=do
 [mode,file,out]<-getArgs
 input<-readFile file
 let flags=case mode of
       "activity"->[]
       "spark"->["-S"]
       "pool"->["-P"]
       "eps"->["-E"]
       "portrait"->["-G"]
       "selected"->["-p[14.1]"]
       _->error "unknown mode"
 let text=P.control input(map parseLine flags)
 writeFile(out++".ps")text
 let(pes,ticks,ordered)=getParameters(parseFile input)
 writeFile(out++".lines")(unlines(map show ordered))
 writeFile(out++".parameters")(show(pes,ticks,length ordered)++"\\n")
 putStrLn(unwords[mode,show(length text),show(hash text)])
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
metadata=[]
for profile,file in [('smoke','gg.faststdin'),('normal','gg.stdin'),('large','gg.slowstdin')]:
 for mode in ['activity','spark','pool','eps','portrait','selected']:
  out=p/(mode+'-'+profile)
  r=subprocess.run([str(d/'observer'),mode,str(d/file),str(out),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap)
  (p/(mode+'-'+profile+'.observe')).write_bytes(r.stdout);(p/(mode+'-'+profile+'.stderr')).write_bytes(r.stderr)
  record=dict(mode=mode,profile=profile,exit=r.returncode,observation=r.stdout.decode().strip(),stderr=r.stderr.decode())
  metadata.append(record);print(record,flush=True)
(p/'observer-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
