from pathlib import Path
import json,subprocess,hashlib
p=Path(__file__).resolve().parent;d=p/'program-source'
names=list(dict.fromkeys(r['benchmark']for r in json.loads((p/'program-cases.json').read_text())))
normal={name:1000 if name.startswith(('int_','caml_'))or name in ['hashtbl_iter','hashtbl_fold']else 100 if name=='hashtbl_filter_map'else 100000 for name in names}
profiles={name:dict(smoke=0 if name.startswith(('int_','caml_'))or name=='hashtbl_remove'else 1001 if name=='hashtbl_find'else 17 if name=='hashtbl_add_duplicate'else 33 if name.startswith('hashtbl_add')else 1,normal=n)for name,n in normal.items()}
for name,n in {'hashtbl_add_resizing':1000000,'hashtbl_add_sized':1000000,'hashtbl_add_duplicate':500000,'hashtbl_filter_map':10000,'caml_hash_int':10000}.items():profiles[name]['large']=n
(p/'profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
up=p.parent/'upstreams/sandmark';config=json.loads((up/'run_config.json').read_text())
entries=[dict(index=i,entry=x)for i,x in enumerate(config['benchmarks'])if x['executable']=='benchmarks/stdlib/hashtbl_bench.exe']
published={}
for item in entries:
 for r in item['entry']['runs']:
  name,n=r['params'].split();assert name not in published;published[name]=int(n)
assert set(published)==set(profiles)
(p/'upstream-run-plan.json').write_text(json.dumps(dict(run_config_sha256=hashlib.sha256((up/'run_config.json').read_bytes()).hexdigest(),entries=entries),indent=2)+'\n')
(p/'published-counts.json').write_text(json.dumps(published,indent=2)+'\n')
calls=[(name,profile,n)for name,ps in profiles.items()for profile,n in ps.items()]
source=(d/'Observer.ml').read_text().split('let ()=List.iter')[0]
source+='let ()=List.iter(fun(name,n)->run name n)['+';'.join('("'+name+'",'+str(n)+')'for name,profile,n in calls)+']\n'
(d/'Profiles.ml').write_text(source)
with(d/'profiles-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','profiles-observer','Observed.ml','Profiles.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'profiles-observer')],cwd=d,timeout=600);(p/'profiles.reference').write_bytes(out)
seed=0x811c9dc5
def mix(h,v):return((h^(v&0xffffffff))*16777619)&0xffffffff
hashes=json.loads((p/'hash-results.json').read_text())
def expected(name,n):
 h=seed
 if name.startswith('int_'):values=[1000]*(n+1)
 elif name.startswith('caml_'):
  column=1 if name=='caml_hash_int'else 2
  values=(r[column]for _ in range(n+1)for r in hashes[:1000])
 elif name=='hashtbl_iter':values=[1000]*n
 elif name=='hashtbl_fold':values=[1001000]*n
 elif name in ['hashtbl_add_sized','hashtbl_add_resizing']:values=[n*(n+1)]
 elif name=='hashtbl_add_duplicate':values=[2*n*(n+1)]
 elif name=='hashtbl_remove':values=[0]*(n//1000+1)
 elif name=='hashtbl_find':values=[i if i<=1000 else 0 for i in range(1,n+1)]
 elif name=='hashtbl_filter_map':values=[sum(i+((i<<min(n,63))&((1<<63)-1))for i in range(1,1001))]
 else:raise AssertionError(name)
 for value in values:h=mix(h,value)
 return str(n)+':'+format(h,'X')
lines=out.decode().splitlines();assert len(lines)==len(calls);results=[]
for(name,profile,n),line in zip(calls,lines):
 recorded,result=line.split();assert recorded==name and result==expected(name,n),(line,expected(name,n))
 results.append(dict(benchmark=name,profile=profile,iterations=n,published=published[name],expected=result))
for row in json.loads((p/'program-cases.json').read_text()):assert row['expected']==expected(row['benchmark'],row['iterations'])
(p/'profile-results.json').write_text(json.dumps(results,indent=2)+'\n')
print('PASS',len(calls),'selected profile results and 56 edge cases against independent iteration, binding and modular models')
