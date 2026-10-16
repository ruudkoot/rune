from pathlib import Path
from decimal import Decimal,localcontext
import subprocess,resource,hashlib,json
ref=Path(__file__).resolve().parent;find=Path.home()/'.opam/default/bin/ocamlfind'
with(ref/'build.log').open('w')as log:subprocess.run([str(find),'ocamlopt','-O2','-package','zarith','-linkpkg','-o','pidigits5','pidigits5.ml'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
with localcontext()as context:
 context.prec=10050;a=Decimal(1);b=1/Decimal(2).sqrt();t=Decimal(1)/4;p=Decimal(1)
 for _ in range(16):
  nexta=(a+b)/2;b=(a*b).sqrt();t-=p*(a-nexta)**2;a=nexta;p*=2
 pi=(a+b)**2/(4*t);digits=format(pi,'f').replace('.','')[:10000]
(ref/'independent-10000.pi').write_text(digits+'\n')
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(120,120))
records=[]
for n in [0,1,10,11,27,128,256,1000,10000]:
 result=subprocess.run([str(ref/'pidigits5'),str(n)],capture_output=True,timeout=135,preexec_fn=bounded);assert result.returncode==0,result.stderr
 expected=(' '*10+'\t:0\n')if n==0 else ''.join(digits[i:min(i+10,n)].ljust(10)+'\t:'+str(min(i+10,n))+'\n'for i in range(0,n,10))
 assert result.stdout==expected.encode(),(n,result.stdout[:40],expected[:40])
 (ref/f'digits-{n}.expected').write_bytes(result.stdout);records.append({'digits':n,'bytes':len(result.stdout),'sha256':hashlib.sha256(result.stdout).hexdigest()});print('PASS original/independent complete digits and layout',n,flush=True)
(ref/'metadata.json').write_text(json.dumps({'ocamlopt':subprocess.check_output([str(find),'ocamlopt','-version'],text=True).strip(),'zarith':subprocess.check_output([str(find),'query','-format','%v','zarith'],text=True).strip(),'cases':records},indent=2)+'\n')
