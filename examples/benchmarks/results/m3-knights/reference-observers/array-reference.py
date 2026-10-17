from pathlib import Path
import shutil,subprocess,json,resource
p=Path(__file__).resolve().parent;d=p/'array-observer-source';shutil.copytree(p/'observer-source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original','observer'),dirs_exist_ok=True)
for name in ['Knights.lhs','KnightHeuristic.lhs']:
 f=d/name;f.write_text(f.read_text().replace('import ChessSetList','import ChessSetArray'))
f=d/'ChessSetArray.lhs';s=f.read_text();assert 'logTen 1 = 0'in s;s=s.replace('logTen 1 = 0','logTen 0 = 0');f.write_text(s)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','array-observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for n,k in [(6,1),(8,1),(8,3),(14,1),(20,1),(4,1),(8,0)]:
 r=subprocess.run([str(d/'array-observer'),str(n),str(k),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
 (p/(str(n)+'-'+str(k)+'.array-tour')).write_bytes(r.stdout);print('array',n,k,len(r.stdout),flush=True)
