from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/gamteb';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
shutil.copyfile(p.parent/'pinned/nofib/common/NofibUtils.hs',d/'NofibUtils.hs')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for profile,n,fixture in [('smoke',100,'gamteb.faststdout'),('normal',1000,'gamteb.stdout'),('large',5000,'gamteb.slowstdout')]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 record=dict(profile=profile,particles=n,repetitions=200,exit=r.returncode,fixture_match=r.stdout==(up/fixture).read_bytes(),stdout_bytes=len(r.stdout))
 records.append(record);print(record,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
