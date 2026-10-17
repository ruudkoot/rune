from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/fft2';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in[('smoke',70),('normal',245),('large',490)]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 assert r.stdout==(d/'fft2.stdout').read_bytes()
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 printed=subprocess.run([str(d/'original'),str(n),'print','+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 (p/(name+'.values')).write_bytes(printed.stdout)
 record=dict(profile=name,base=n,iterations=100,fixture_match=True,printed_lines=len(printed.stdout.splitlines()));records.append(record);print(record,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
