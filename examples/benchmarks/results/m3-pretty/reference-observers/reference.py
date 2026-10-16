from pathlib import Path
import subprocess,resource,json
r=Path(__file__).resolve().parent
for source,exe in [('Main.hs','original'),('Observer.hs','observer')]:
 with(r/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,source],cwd=r,check=True,stdout=log,stderr=subprocess.STDOUT)
raw=subprocess.check_output([str(r/'original')]);assert raw==(r/'pretty.stdout').read_bytes()
def bounded():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
meta=[]
for width,n in [(0,0),(10,0),(18,0),(80,0),(22,1),(23,1),(20,10),(80,50),(317,50),(318,50),(80,5000)]:
 raw=subprocess.check_output([str(r/'observer'),str(width),str(n)],timeout=180,preexec_fn=bounded)
 prefix='-42@This is a string\n, \n';words=' '.join(['xxxxx']*n);horizontal=width>=17+6*n if n else width>=18
 expected=prefix+'This is the label'+(' '+words if horizontal else'\n'+('\t'+words if n else''))+'\n';assert raw==expected.encode(),(width,n,raw,expected)
 (r/(f'{width}-{n}.output')).write_bytes(raw);meta.append(dict(width=width,words=n,bytes=len(raw),comparison='complete original output and independent main-document layout'))
 print('PASS original/independent full layout',width,n,len(raw),'bytes',flush=True)
(r/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
