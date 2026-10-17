from pathlib import Path
import subprocess,shutil,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/benchmarksgame';d=p/'source';d.mkdir(exist_ok=True)
for file in ['regexredux2.ml','fasta3.ml','dune','README.md','LICENSE']:
 if(up/file).exists():shutil.copy(up/file,d/file)
with(d/'build.log').open('w')as f:
 subprocess.run(['ocamlopt','str.cmxa','regexredux2.ml','-o','original'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 subprocess.run(['ocamlopt','fasta3.ml','-o','fasta-original'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,n in [('smoke',100),('normal',50000),('large',500000)]:
 file=p/(profile+'.fasta')
 with file.open('wb')as f:subprocess.run([str(d/'fasta-original'),str(n)],cwd=d,stdout=f,stderr=subprocess.PIPE,preexec_fn=cap,timeout=120,check=True)
 shutil.copy(file,d/'input5000000.txt');t=time.monotonic()
 r=subprocess.run([str(d/'original')],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=120,preexec_fn=cap,check=True)
 (p/(profile+'.output')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 records.append(dict(profile=profile,fasta_parameter=n,bytes=file.stat().st_size,original_result_bytes=len(r.stdout),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ocaml=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),runs=records),indent=2)+'\n')
