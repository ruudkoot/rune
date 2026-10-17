from pathlib import Path
import subprocess,resource,shutil,json,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/multiplier';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,width,fixture in [('smoke',32,'multiplier.faststdout'),('normal',256,'multiplier.stdout'),('large',512,'multiplier.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(width),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr);assert r.stdout==(d/fixture).read_bytes()
 records.append(dict(profile=profile,width=width,clock_cycles=2000,bytes=len(r.stdout),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'smoke-short.trace').write_bytes(b''.join((p/'smoke.stdout').read_bytes().splitlines(keepends=True)[:17]))
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
