from pathlib import Path
import ast,subprocess,json
ref=Path(__file__).resolve().parent
with(ref/'random-observer-build.log').open('w')as log:subprocess.run(['ghc','-cpp','-O2','-fforce-recomp','-o','random-observer','RandomObserver.hs','random-1.1/Random.hs'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
perms=json.loads((ref/'permutations.json').read_text());demand=json.loads((ref/'demand.json').read_text());rngrows=[]
for mode in ['rng','permutation','demand']:
 raw=subprocess.check_output([str(ref/'random-observer'),mode],text=True,timeout=120);(ref/(mode+'-ghc.txt')).write_text(raw)
 for line in raw.splitlines():
  seed,values=ast.literal_eval(line)
  if mode=='rng':
   s1=seed%2147483562+1;s2=seed//2147483562%2147483398+1
   for i,(x,state)in enumerate(values):
    s1=s1*40014%2147483563;s2=s2*40692%2147483399;z=s1-s2
    if z<1:z+=2147483562
    assert z==x and [int(v)for v in state.split()]==[s1,s2]
    rngrows.append([seed,i+1,z,s1,s2,1+(z-1)%100])
  elif mode=='permutation':assert values==list(zip(perms[str(seed)]['values'],perms[str(seed)]['positions']))
  else:
   for k,success,lazy,strict in values:
    row=next(r for r in demand if r['seed']==seed and r['k']==k)
    assert [success,lazy,strict]==[row['success'],row['lazy_draws'],row['strict_draws']]
 print('PASS complete GHC/independent',mode,flush=True)
(ref/'random.expected').write_text(''.join(' '.join(str(n)for n in row)+'\n'for row in rngrows))
(ref/'demand.expected').write_text(''.join(' '.join([str(r['seed']),str(r['k']),'1'if r['success']else'0',str(r['lazy_draws']),str(r['strict_draws'])])+'\n'for r in demand))
for seed,row in perms.items():(ref/('permutation-'+seed+'.expected')).write_text(' '.join(str(n)for n in row['values'])+'\n')
