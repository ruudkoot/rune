from pathlib import Path
import subprocess,shutil,resource,json,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib'
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for family in ['gc','real']:
 d=p/family/'source';shutil.copytree(up/family/'fulsom',d,dirs_exist_ok=True)
 with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 cases=[('source-fast',7),('normal',9)]if family=='gc'else[('source-fast',4),('normal',5),('source-slow',6)]
 for profile,depth in cases:
  t=time.monotonic();r=subprocess.run([str(d/'original'),str(depth),'+RTS','-M512m','-RTS'],cwd=d,capture_output=True,timeout=600,preexec_fn=cap,check=True)
  out=p/family/(profile+'.stdout');out.write_bytes(r.stdout);(p/family/(profile+'.stderr')).write_bytes(r.stderr)
  fixture=d/('fulsom.'+('faststdout'if profile=='source-fast'else'slowstdout'if profile=='source-slow'else'stdout'))
  assert r.stdout==fixture.read_bytes(),(family,profile)
  row=dict(family=family,profile=profile,depth=depth,bytes=len(r.stdout),seconds=time.monotonic()-t)
  records.append(row);print(row,flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
