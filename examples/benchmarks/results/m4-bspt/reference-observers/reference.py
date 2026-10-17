from pathlib import Path
import shutil,subprocess,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/bspt';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in [('smoke',1),('normal',25000),('large',125000)]:
 start=time.monotonic()
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,input=(d/'bspt.stdin').read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 fixture=d/('bspt'+('.fast'if name=='smoke'else'.slow'if name=='large'else'.')+'stdout')
 original=fixture.read_bytes()
 expected_line=original.splitlines()[0]
 assert len(r.stdout.splitlines())==n and all(line==expected_line for line in r.stdout.splitlines())
 record=dict(profile=name,repetitions=n,source_fixture_lines=len(original.splitlines()),all_result_lines_match=True,hash=expected_line.decode(),elapsed_seconds=time.monotonic()-start)
 records.append(record);print(record,flush=True)
obs=p/'observer-source';shutil.copytree(up,obs,dirs_exist_ok=True)
(obs/'Observer.hs').write_text("""module Main where
import Prog
main = getContents >>= putStr . prog
""")
with(obs/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=obs,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(obs/'observer')],cwd=obs,input=(obs/'bspt.stdin').read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
(p/'batch.render').write_bytes(r.stdout);print('complete batch output',len(r.stdout),'bytes',flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
