from pathlib import Path
import subprocess,resource,time,json,hashlib
ref=Path(__file__).resolve().parent
with(ref/'build.log').open('w')as log:subprocess.run(['ocamlopt','-O2','-o','observer','observer.ml'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3));resource.setrlimit(resource.RLIMIT_CPU,(180,180))
records=[]
for label,args in [('tiny',['3','2','0']),('smoke',['16','16','128']),('normal',['128','128','10000']),('large',['1000','1000','100000'])]:
 start=time.monotonic();r=subprocess.run([str(ref/'observer'),*args],capture_output=True,timeout=195,preexec_fn=bounded);assert r.returncode==0,r.stderr
 target=ref/(label+'.expected')
 if target.exists():assert target.read_bytes()==r.stdout
 else:target.write_bytes(r.stdout)
 records.append({'profile':label,'args':args,'seed':42,'seconds':time.monotonic()-start,'bytes':len(r.stdout),'sha256':hashlib.sha256(r.stdout).hexdigest()});print('PASS deterministic source population',label,flush=True)
(ref/'metadata.json').write_text(json.dumps({'ocamlopt':subprocess.check_output(['ocamlopt','-version'],text=True).strip(),'options':['-O2'],'profiles':records},indent=2)+'\n')
