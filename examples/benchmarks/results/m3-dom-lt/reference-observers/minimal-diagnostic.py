from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent;f=p/'cases/minimal.in';f.write_text('(0,[(0,[1,2]),(1,[]),(2,[1])])\n')
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
records=[]
for name,d,executable in [('source-O2',p/'observer-source','observer'),('corrected-O2',p/'repair-threshold','observer')]:
 r=subprocess.run([str(d/executable),str(f),'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
 (p/(name+'-minimal.parents')).write_bytes(r.stdout);records.append(dict(variant=name,result=r.stdout.decode().strip()))
d=p/'observer-source'
with(d/'build-O0.log').open('w')as log:subprocess.run(['ghc','-O0','-rtsopts','-fforce-recomp','-o','observer-O0','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'observer-O0'),str(f),'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
(p/'source-O0-minimal.parents').write_bytes(r.stdout);records.append(dict(variant='source-O0',result=r.stdout.decode().strip()))
(p/'minimal-diagnostic.json').write_text(json.dumps(records,indent=2)+'\n')
for row in records:print(row,flush=True)
