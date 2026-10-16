from pathlib import Path
import subprocess,resource,json,hashlib
root=Path.cwd();p=Path(__file__).resolve().parent;up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/benchmarksgame/binarytrees5.ml'
(p/'binarytrees5.ml').write_bytes(up.read_bytes())
with(p/'build.log').open('w')as log:subprocess.run(['ocamlopt','-O2','-o','original','binarytrees5.ml'],cwd=p,check=True,stdout=log,stderr=subprocess.STDOUT)
profiles=[]
for profile,n,timeout,memory in [('smoke',6,30,1024**3),('normal',16,600,4*1024**3),('large',21,3600,8*1024**3)]:
 def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
 original=subprocess.run([str(p/'original'),str(n)],capture_output=True,check=True,timeout=timeout,preexec_fn=limits).stdout
 lines=[f'stretch tree of depth {n+1}\t check: {(1<<(n+2))-1}\n']
 for depth in range(4,n+1,2):
  count=1<<(n-depth+4);lines.append(f'{count}\t trees of depth {depth}\t check: {count*((1<<(depth+1))-1)}\n')
 lines.append(f'long lived tree of depth {n}\t check: {(1<<(n+1))-1}\n')
 assert original==''.join(lines).encode();(p/(str(n)+'.expected')).write_bytes(original)
 profiles.append({'profile':profile,'depth':n,'timeout':timeout,'memory_bytes':memory,'output_sha256':hashlib.sha256(original).hexdigest()})
 print('PASS original binarytrees5 and independent complete-tree formulas',profile,n,flush=True)
(p/'metadata.json').write_text(json.dumps({'source_sha256':hashlib.sha256(up.read_bytes()).hexdigest(),'ocaml_version':subprocess.check_output(['ocamlopt','-version'],text=True).strip(),'profiles':profiles},indent=2)+'\n')
