from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/gg';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
shutil.copyfile(p.parent/'pinned/nofib/common/NofibUtils.hs',d/'NofibUtils.hs')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for profile,n,inputName,outputName in [('smoke',150,'gg.faststdin','gg.faststdout'),('normal',500,'gg.stdin','gg.stdout'),('large',1500,'gg.slowstdin','gg.slowstdout')]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,input=(d/inputName).read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 record=dict(profile=profile,repetitions=n,fixture_match=r.stdout==(d/outputName).read_bytes(),stderr_match=r.stderr==(d/'gg.stderr').read_bytes(),stdout_bytes=len(r.stdout));records.append(record);print(record,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
