from pathlib import Path
import subprocess,shutil,resource,json,time,hashlib
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/gc/happy';o=p/'source'
shutil.copytree(up,o,dirs_exist_ok=True)
with(p/'build.log').open('w')as log:
 r=subprocess.run(['ghc','-O2','-cpp','-rtsopts','-fforce-recomp','Main.lhs','-o','original'],cwd=o,stdout=log,stderr=subprocess.STDOUT)
(p/'build-exit.json').write_text(json.dumps({'exit':r.returncode,'adapter':'none; unmodified pinned sources'},indent=2)+'\n')
r.check_returncode()
def cap():resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
start=time.monotonic()
r=subprocess.run([str(o/'original'),'TestInput.y','+RTS','-M1g','-RTS'],cwd=o,capture_output=True,timeout=600,preexec_fn=cap)
(p/'normal.stdout').write_bytes(r.stdout);(p/'normal.stderr').write_bytes(r.stderr)
r.check_returncode()
assert r.stderr==(o/'happy.expected').read_bytes()
output=(o/'TestInput.hs').read_bytes();(p/'TestInput.generated.reference').write_bytes(output)
(p/'reference-results.json').write_text(json.dumps({'exit':r.returncode,'seconds':time.monotonic()-start,'stdout_bytes':len(r.stdout),'stderr_matches_upstream':True,'generated_bytes':len(output),'generated_sha256':hashlib.sha256(output).hexdigest()},indent=2)+'\n')
print((p/'reference-results.json').read_text())
