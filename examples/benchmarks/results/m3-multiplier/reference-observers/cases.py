from pathlib import Path
import subprocess,resource,shutil,json
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
f=d/'Main.hs';(d/'Circuit.hs').write_text(f.read_text().replace('module Main where','module Circuit where'))
(d/'Observer.hs').write_text('''module Main where
import Circuit
import System.Environment
main = do
 [mode,w,c] <- getArgs
 let width=read w; cycles=read c; inputs=[(2+3*i,11+2*i) | i<-[1..]]
 putStr (if mode=="trace" then traceMult 10 width cycles inputs else runMult width cycles inputs)
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=p/'cases';out.mkdir(exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
def model(width,clocks):
 ra=rb=prod=0;next_input=1;rows=[];count=0;mask=(1<<(2*width))-1;input_mask=(1<<width)-1
 def signed(n):return str((n%(1<<64))-(1<<64)if n%(1<<64)>=1<<63 else n%(1<<64))
 for cycle in range(clocks):
  ready=int(ra==0 or rb==0);count+=ready
  if ready:a=(2+3*next_input)&input_mask;b=(11+2*next_input)&input_mask;next_input+=1
  else:a=b=0
  rows.append(str(cycle).rjust(5)+'. '+str(ready)+signed(a).rjust(10)+signed(b).rjust(10)+'  ==> '+str(ready)+signed(ra).rjust(10)+signed(rb).rjust(10)+signed(prod).rjust(10)+'\n')
  prod=0 if ready else(prod+(ra if rb&1 else 0))&mask
  ra=a if ready else(ra<<1)&mask
  rb=b if ready else rb>>1
 return ''.join(rows),count
records=[]
for width,cycles in [(1,16),(2,32),(4,32),(8,64),(32,16),(32,2000),(256,2000),(512,2000)]:
 expected,count=model(width,cycles)
 for mode in ['trace','count']:
  r=subprocess.run([str(d/'observer'),mode,str(width),str(cycles),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
  wanted=expected if mode=='trace'else str(count)+'\n';assert r.stdout==wanted.encode(),(width,cycles,mode)
  (out/(str(width)+'-'+str(cycles)+'.'+mode)).write_bytes(r.stdout)
 records.append(dict(width=width,cycles=cycles,ready_count=count,independent_matches=True));print(records[-1],flush=True)
(p/'case-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
