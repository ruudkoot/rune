from pathlib import Path
import subprocess,re,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/sched';d=p/'observer-source';d.mkdir(exist_ok=True)
source=(p/'source/Main.hs').read_text()
source=re.sub(r'module Main \(main\) -- sched\s+where', 'module SchedSource where',source)
(d/'SchedSource.hs').write_text(source)
cases=[(n,t)for n in [0,1,2,3,7,10,11,12,14]for t in sorted({0,max(0,n-3),100})]
observer='''module Main where
import SchedSource
import Data.Bits
import Data.Word
input n=case n of
 1->c_solo;3->c_trio;7->c_septiem;10->c_deciem;11->c_undeciem;12->c_duodeciem;14->c_quadrideciem;_->C_EMPTYJOBDEF
mix :: Word32 -> Int -> Word32
mix h n=(xor h (fromIntegral n))*16777619
walk h (F_LEAF n)=(1,n,n,toInteger n,mix h n)
walk h (F_TREE a b)=
 let (ca,la,ha,sa,x)=walk(mix h 1)a
     (cb,lb,hb,sb,y)=walk(mix x 2)b
 in(ca+cb,min la lb,max ha hb,sa+sb,y)
showCase(n,t)=
 let tree=f_sched(input n)t
     (count,low,high,total,hash)=walk 2166136261 tree
 in putStrLn(unwords(map show[n,t,count,low,high])++" "++show total++" "++show hash)
main=mapM_ showCase '''+str(cases).replace(' ', '')+'\n'
(d/'Observer.hs').write_text(observer)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-I'+str(up),'-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer'),'+RTS','-M512m','-RTS'],cwd=d,timeout=300)
(p/'observations.reference').write_bytes(out)
rows=[list(map(int,line.split()))for line in out.decode().splitlines()];assert len(rows)==len(cases)
(p/'observations.json').write_text(json.dumps(rows,indent=2)+'\n')
print('PASS',len(rows),'original complete schedule-tree counts/min/max/sums/ordered hashes')
