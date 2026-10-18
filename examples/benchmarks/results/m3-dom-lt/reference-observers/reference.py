from pathlib import Path
import subprocess,shutil,resource,json,time,ast
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/dom-lt';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
graphs=[ast.literal_eval(line)for line in(d/'ghc-examples.in').read_text().splitlines()]
for root,adj in graphs:
 keys={key for key,_ in adj}
 assert root in keys and all(value in keys for _,targets in adj for value in targets)
records=[]
for profile,n,fixture in [('smoke',0,None),('source-fast',50,'dom-lt.faststdout'),('normal',400,'dom-lt.stdout'),('large',2000,'dom-lt.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),'ghc-examples.in',str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 if fixture:assert r.stdout==(d/fixture).read_bytes()
 records.append(dict(profile=profile,argument=n,passes=n+1,result=r.stdout.decode().strip(),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),containers=subprocess.check_output(['ghc-pkg','field','containers','version'],text=True).strip(),graphs=len(graphs),runs=records),indent=2)+'\n')
