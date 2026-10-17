from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/lambda';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in [('smoke',80),('normal',260),('large',550)]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 assert r.stdout==(d/('lambda'+('.fast'if name=='smoke'else'.slow'if name=='large'else'.')+'stdout')).read_bytes()
 expected=n*(n+1)//2;rows=r.stdout.decode().splitlines()
 assert len(rows)==200 and all(rows[i]=='Con '+str(expected)and rows[i+1]==str(expected)+'  []'for i in range(0,200,2))
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 records.append(dict(profile=name,n=n,iterations=100,result=expected,fixture_match=True))
 print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
