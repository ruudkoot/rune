from pathlib import Path
import shutil,subprocess,json,resource,time
p=Path(__file__).resolve().parent;src=p/'source';out=p/'array-source';shutil.copytree(src,out,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
s=(out/'ChessSetArray.lhs').read_text().replace('module ChessSetArray(Tile,','module ChessSetArray(Tile, spaces,');(out/'ChessSetArray.lhs').write_text(s)
(out/'ArrayObserver.hs').write_text('''module Main where
import ChessSetArray
main = print (length (spaces 64 1))
''')
with(out/'build.log').open('w')as f:subprocess.run(['ghc','-O0','-rtsopts','-o','array-observer','ArrayObserver.hs'],cwd=out,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
t=time.monotonic()
try:
 r=subprocess.run([str(out/'array-observer'),'+RTS','-M64m','-K8m','-RTS'],cwd=out,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=3,preexec_fn=cap)
 result=dict(status='exit',exit_code=r.returncode,stdout=r.stdout.decode(errors='replace'),stderr=r.stderr.decode(errors='replace'))
except subprocess.TimeoutExpired as e:
 result=dict(status='timeout',seconds=3,stdout=(e.stdout or b'').decode(errors='replace'),stderr=(e.stderr or b'').decode(errors='replace'))
result['elapsed_seconds']=time.monotonic()-t
(p/'array-diagnostic.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
