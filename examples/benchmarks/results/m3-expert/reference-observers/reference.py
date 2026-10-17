from pathlib import Path
import subprocess,shutil,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/expert';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n,fixture in [('smoke',1,'expert.faststdout'),('normal',10000,'expert.stdout'),('large',50000,'expert.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,input=(d/'expert.stdin').read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 expected=(d/fixture).read_bytes().splitlines();assert len(r.stdout.splitlines())==n and all(line==expected[0]for line in r.stdout.splitlines())
 records.append(dict(profile=name,repetitions=n,expected_length=int(expected[0]),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
