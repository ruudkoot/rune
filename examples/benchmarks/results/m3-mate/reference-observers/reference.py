from pathlib import Path
import shutil,subprocess,resource,json,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/mate';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for profile,name,fixture in [('smoke','heathcote3','mate.faststdout'),('normal','kohtz','mate.stdout'),('large','holzhausen','mate.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),'runtime_files/'+name+'.prob','+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 records.append(dict(profile=profile,problem=name,fixture_match=r.stdout==(d/fixture).read_bytes(),elapsed_seconds=time.monotonic()-t,bytes=len(r.stdout)));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
