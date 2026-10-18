from pathlib import Path
import subprocess,re,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/wave4main';d=p/'observer-source';d.mkdir(exist_ok=True)
source=(p/'source/Main.hs').read_text()
source=re.sub(r'module Main \(main\) -- wave4main\s+where','module WaveSource where',source)
(d/'WaveSource.hs').write_text(source)
steps=[0,1,2,3,8,16,40,80,400]
observer='''module Main where
import WaveSource
import Data.Array
showArray name a=
 let (lo,hi)=bounds a
     (low,high)=bounds(a!lo)
 in do
 putStrLn(unwords["matrix",name,show lo,show hi,show low,show high])
 mapM_ (putStrLn.show) [a!i!j|i<-[lo..hi],j<-[low..high]]
run n=
 let solution@((lu,lv,lh),(ru,rv,rh))=f_solution n
 in do
 putStrLn("steps "++show n)
 putStrLn("sumcode "++f_sumcode(f_output_print solution))
 mapM_ (uncurry showArray)[("lu",lu),("ru",ru),("lv",lv),("rv",rv),("lh",lh),("rh",rh)]
main=mapM_ run '''+str(steps).replace(' ','')+'\n'
(d/'Observer.hs').write_text(observer)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-I'+str(up),'-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer'),'+RTS','-M512m','-RTS'],cwd=d,timeout=180)
(p/'observations.reference').write_bytes(out)
records=[]
for block in out.decode().split('steps ')[1:]:
 lines=[x for x in block.splitlines()if x];step=int(lines[0]);sumcode=lines[1].split()[1];matrices=[];i=2
 while i<len(lines):
  fields=lines[i].split();assert fields[0]=='matrix'
  name=fields[1];lo,hi,low,high=map(int,fields[2:]);n=(hi-lo+1)*(high-low+1)
  cells=list(map(float,lines[i+1:i+n+1]));assert len(cells)==n
  matrices.append(dict(name=name,bounds=[lo,hi,low,high],cells=cells));i+=n+1
 assert len(matrices)==6
 records.append(dict(steps=step,sumcode=sumcode,matrices=matrices))
(p/'observations.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS',len(records),'complete original split-grid states, bounds and print checksums')
