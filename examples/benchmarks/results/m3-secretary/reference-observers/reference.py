from pathlib import Path
import subprocess,resource,json,hashlib
ref=Path(__file__).resolve().parent
source=(ref/'Main.lhs').read_text();source=source.replace('module Main where','module Kernel where').replace('sim :: Int -> Double','simN :: Int -> Int -> Int').replace('sim k = simulate 5000 100 proc','simN n k = simulateCount n 100 proc').replace('main = print [ sim k | k <- [35..39] ]','main = print [ simN 5000 k | k <- [35..39] ]')
# Preserve the original processing/demand expressions; expose only the numerator.
source=source.replace('simulate n m proc = length (filter id tries) // n','simulate n m proc = fromIntegral (simulateCount n m proc) / fromIntegral n\n\nsimulateCount :: Int -> Integer -> Process -> Int\nsimulateCount n m proc = length (filter id tries)')
(ref/'Kernel.lhs').write_text(source)
(ref/'Observer.hs').write_text('''module Main where
import Kernel
import System.Random
import Data.List
import System.Environment
main=do
 [arg]<-getArgs
 let n=read arg
 print [simN n k|k<-[35..39]]
''')
with(ref/'observer-build.log').open('w')as log:subprocess.run(['ghc','-cpp','-O2','-fforce-recomp','-o','observer','Observer.hs','Kernel.lhs','random-1.1/Random.hs'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
def limit():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(600,600))
def permutation(seed):
 s1=(seed&2147483647)%2147483562+1;s2=((seed&2147483647)//2147483562)%2147483398+1
 seen=set();values=[];positions=[];draws=0
 while len(values)<100:
  s1=s1*40014%2147483563;s2=s2*40692%2147483399;z=s1-s2
  if z<1:z+=2147483562
  value=1+(z-1)%100;draws+=1
  if value not in seen:seen.add(value);values.append(value);positions.append(draws)
 return values,positions
allcounts=[0]*5;meta=[];selected={1,2,42,50,5000,50000};perms={};demand=[]
for seed in range(1,50001):
 values,positions=permutation(seed)
 if seed in selected:
  perms[str(seed)]={'values':values,'positions':positions}
 for index,k in enumerate(range(35,40)):
  best=max(values[:k]);candidates=[i for i in range(k,100)if values[i]>=best]
  at=candidates[0]if candidates else None;success=at is not None and values[at]==100
  allcounts[index]+=success
  if seed in selected:demand.append(dict(seed=seed,k=k,success=success,lazy_draws=positions[at]if at is not None else positions[-1],strict_draws=positions[-1]))
 if seed in [50,500,5000,50000]:
  raw=subprocess.check_output([str(ref/'observer'),str(seed)],timeout=615,preexec_fn=limit).decode();counts=json.loads(raw);assert counts==allcounts,(seed,counts,allcounts)
  (ref/(str(seed)+'.expected')).write_text(raw);meta.append(dict(trials=seed,ks=list(range(35,40)),counts=counts,comparison='complete original processing expression versus independent full-permutation/set model'))
  print('PASS GHC original count expression and independent complete permutation model',seed,counts,flush=True)
(ref/'permutations.json').write_text(json.dumps(perms,indent=2)+'\n');(ref/'demand.json').write_text(json.dumps(demand,indent=2)+'\n');(ref/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert [float(x)/5000 for x in next(row for row in meta if row['trials']==5000)['counts']]==json.loads((ref/'secretary.stdout').read_text())
print('PASS exact pinned upstream probability fixture')
