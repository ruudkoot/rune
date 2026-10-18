from pathlib import Path
import json,subprocess,hashlib,collections
p=Path(__file__).resolve().parent;d=p/'observer-source';up=p.parent/'upstreams/sandmark'
data=json.loads((up/'run_config.json').read_text());selected=[(i,x)for i,x in enumerate(data['benchmarks'])if x['executable']in ['benchmarks/stdlib/bytes_bench.exe','benchmarks/stdlib/string_bench.exe']]
published={}
for _,entry in selected:
 for run in entry['runs']:
  name,n=run['params'].split();assert name not in published;published[name]=int(n)
names=[row.split()[0]for row in(p/'results.reference').read_text().splitlines()[::4]]
assert set(names)==set(published)
normal={}
for name in names:
 key=name.split('_',1)[1]
 normal[name]=100 if key in ['compare','equal']else 2000 if key in ['cat','iter','map','uppercase_ascii','split_on_char']else 200000 if key in ['get','set','index','contains']else 20000
large={'bytes_map':100000,'string_map':100000,'string_split_on_char':50000,'string_compare':10000,'bytes_set':1000000}
profiles={name:dict(smoke=575 if name.split('_',1)[1]in ['get','set','sub','blit']else 1,normal=normal[name])for name in names}
for name,n in large.items():profiles[name]['large']=n
(p/'profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
(p/'upstream-run-plan.json').write_text(json.dumps(dict(run_config_sha256=hashlib.sha256((up/'run_config.json').read_bytes()).hexdigest(),entries=[dict(index=i,entry=x)for i,x in selected]),indent=2)+'\n')
(p/'published-counts.json').write_text(json.dumps(published,indent=2)+'\n')
calls=[(name,profile,n)for name,ps in profiles.items()for profile,n in ps.items()]
source=(d/'Observer.ml').read_text().split('let ()=List.iter')[0]
source+='let ()=List.iter(fun(name,n)->run name n)['+';'.join('("'+name+'",'+str(n)+')'for name,profile,n in calls)+']\n'
(d/'Profiles.ml').write_text(source)
with(d/'profiles-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','profiles-observer','bytes_observed.ml','string_observed.ml','Profiles.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'profiles-observer')],cwd=d,timeout=600);(p/'profiles.reference').write_bytes(out)
text=(p/'text.reference').read_bytes();seed=0x811c9dc5
def mix(h,v):return((h^v)*16777619)&0xffffffff
def digest(data,h=seed):
 for c in data:h=mix(h,c)
 return h
def expected(name,n):
 key=name.split('_',1)[1];h=seed
 fixed={'cat':digest(b'I AM A FISH'+text),'concat':digest(b'I AM A FISH'),'iter':len(text),'map':digest(b'!'*len(text)),'trim':digest(b'We need a trim'),'index':text.index(b'r'),'contains':1,'uppercase_ascii':digest(text.upper()),'compare':0,'equal':sum(v*v for v in collections.Counter(text.split(b' ')).values())}
 parts=seed
 for word in text.split(b' '):parts=mix(digest(word,parts),0)
 fixed['split_on_char']=parts
 if key=='get':values=list(text)
 elif key in ['sub','blit']:
  size=2 if key=='sub'else 32;values=[digest(text[i:i+size])for i in range(len(text)-size)]
 elif key=='set':values=[0]
 else:values=[fixed[key]]
 for i in range(1,n+1):h=mix(h,values[i%len(values)])
 if key=='set':
  array=bytearray(text)
  for i in range(1,min(n,len(text))+1):array[i%len(text)]=32
  h=mix(h,digest(array))
 return str(n)+':'+format(h,'X')
lines=out.decode().splitlines();assert len(lines)==len(calls);results=[]
for(name,profile,n),line in zip(calls,lines):
 actual,result=line.split();assert actual==name and result==expected(name,n),(name,n,result,expected(name,n))
 results.append(dict(benchmark=name,profile=profile,iterations=n,published=published[name],expected=result))
(p/'profile-results.json').write_text(json.dumps(results,indent=2)+'\n')
print('PASS',len(calls),'original selected profile results and independent byte/word models')
