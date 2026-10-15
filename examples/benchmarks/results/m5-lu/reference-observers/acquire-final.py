from pathlib import Path
import subprocess,resource,hashlib,json
p=Path(__file__).parent;up=Path('tests/out/benchmarks/upstreams/sandmark/benchmarks/multicore-numerical/LU_decomposition.ml');saved=p/'acquired';saved.mkdir(exist_ok=True)
source=up.read_text().replace('  ()','''  let output filename a = let out=open_out filename in
    Array.iter(fun x -> Printf.fprintf out "%.17g\\n" x)a;close_out out in
  output Sys.argv.(2) lu;output(Sys.argv.(2)^".input") a''')
(p/'lu_final_observer.ml').write_text(source);command=['ocamlopt','-O2','-o',str(p/'final-observer'),str(p/'lu_final_observer.ml')]
subprocess.run(command,check=True)
meta={'upstream':'5605805954a00497ed197c930641cddd580e1507','source':str(up),'source_sha256':hashlib.sha256(up.read_bytes()).hexdigest(),'compile':command,'ocamlopt':subprocess.check_output(['ocamlopt','-version']).decode().strip(),'profiles':[]}
for profile,n,seconds,memory in [('smoke',4,30,1024**3),('normal',256,600,4*1024**3),('large',1024,3600,8*1024**3)]:
 def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
 result=subprocess.run([str(p/'final-observer'),str(n),str(saved/(profile+'.lu'))],capture_output=True,timeout=seconds,preexec_fn=limits,check=True)
 assert not result.stdout
 meta['profiles'].append({'profile':profile,'size':n,'timeout':seconds,'memory_bytes':memory,'exit':result.returncode,'factors_sha256':hashlib.sha256((saved/(profile+'.lu')).read_bytes()).hexdigest(),'input_sha256':hashlib.sha256((saved/(profile+'.lu.input')).read_bytes()).hexdigest()})
 print('PASS bounded original LU',profile,n,flush=True)
(saved/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
