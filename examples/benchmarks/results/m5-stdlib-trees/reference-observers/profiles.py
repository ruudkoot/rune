from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parent;d=p/'program-source'
normal={'map_iter':1000,'map_add':100000,'map_add_duplicate':100000,'map_remove':1000000,'map_fold':1000,'map_for_all':1000,'map_find':1000000,'map_map':1000,'set_fold':10000,'set_mem':1000000,'set_add_rem':100000}
large={'map_add':1000000,'map_add_duplicate':1000000,'map_map':10000,'set_fold':1000000,'set_mem':50000000,'set_add_rem':20000000}
profiles={name:dict(smoke=1,normal=n)for name,n in normal.items()}
for name,n in large.items():profiles[name]['large']=n
# Boundary membership profiles exercise both present and absent keys.
profiles['map_find']['smoke']=10001;profiles['set_mem']['smoke']=1001
(p/'profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
src=(d/'Observer.ml').read_text();src=src[:src.index('let ()=List.iter')]
calls=[(name,profile,n)for name,ps in profiles.items()for profile,n in ps.items()]
src+='let ()=List.iter(fun(name,n)->run name n)['+';'.join('("'+name+'",'+str(n)+')'for name,profile,n in calls)+']\n'
(d/'Profiles.ml').write_text(src)
with(d/'profiles-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','profiles-observer','map_observed.ml','set_observed.ml','Profiles.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'profiles-observer')],cwd=d,timeout=600)
(p/'profiles.reference').write_bytes(out)
# Algebraic oracle is independent of tree code and instrumented source.
def expected(name,n):
 if name=='map_iter':return n*10000
 if name in ['map_add','map_add_duplicate']:return n*(n+1)
 if name=='map_remove':return 99990000
 if name=='map_fold':return n*99990000
 if name=='map_for_all':return n
 if name=='map_find':return min(n,9999)
 if name=='map_map':return n*149985000
 if name=='set_fold':return n*500500
 if name=='set_mem':return min(n,1000)
 if name=='set_add_rem':return sum(range(min(n,1000)+1,1001))
results=[]
for (name,profile,n),line in zip(calls,out.decode().splitlines()):
 recorded,count,digest=line.split();assert recorded==name and int(count)==n
 assert int(digest,16)==expected(name,n)%(2**32)
 results.append(dict(benchmark=name,profile=profile,iterations=n,expected=digest))
assert len(results)==len(calls)
(p/'profile-results.json').write_text(json.dumps(results,indent=2)+'\n')
print('PASS',len(calls),'fixed original profile digests against independent models')
