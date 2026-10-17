from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/prolog';source=p/'source';shutil.copytree(up,source,dirs_exist_ok=True)
shutil.copyfile(p.parent/'pinned/nofib/common/NofibUtils.hs',source/'NofibUtils.hs')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for engine,filename in [('stack','Engine.hs'),('pure','PureEngine.hs')]:
 d=p/engine;shutil.copytree(source,d,dirs_exist_ok=True)
 shutil.copyfile(source/filename,d/'Engine.hs')
 with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 for profile in ['fast','','slow']:
  stem='prolog.'+profile if profile else'prolog.'
  inputfile=source/(stem+'stdin');fixture=source/(stem+'stdout')
  label=profile or'normal'
  try:
   r=subprocess.run([str(d/'original'),'+RTS','-M512m','-RTS'],cwd=d,input=inputfile.read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap)
   (d/(label+'.stdout')).write_bytes(r.stdout);(d/(label+'.stderr')).write_bytes(r.stderr)
   record=dict(engine=engine,profile=label,exit=r.returncode,bytes=len(r.stdout),fixture_match=r.stdout==fixture.read_bytes())
  except subprocess.TimeoutExpired as e:
   record=dict(engine=engine,profile=label,status='timeout',seconds=300)
   (d/(label+'.stdout')).write_bytes(e.stdout or b'');(d/(label+'.stderr')).write_bytes(e.stderr or b'')
  records.append(record);print(record,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',runs=records),indent=2)+'\n')
