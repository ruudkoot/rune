from pathlib import Path
import subprocess,shutil,json,resource,re
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/mkhprog';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
shutil.copyfile(p.parent/'pinned/nofib/common/NofibUtils.hs',d/'NofibUtils.hs')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for n in[1,10,350,3800,18000]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-s','-M512m','-RTS'],cwd=d,input=(d/'mkhprog.stdin').read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 assert r.stdout==b''
 (p/(str(n)+'.stdout')).write_bytes(r.stdout);(p/(str(n)+'.stderr')).write_bytes(r.stderr)
 match=re.search(rb'([\d,]+) bytes allocated in the heap',r.stderr)
 record=dict(repetitions=n,exit=r.returncode,stdout_empty=True,allocated_bytes=int(match[1].replace(b',',b''))if match else None)
 records.append(record);print(record,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),profiles=records,scope='Unmodified nofib program; RTS allocation diagnostics investigate sharing across repetitions, not headline timing'),indent=2)+'\n')
