from pathlib import Path
import subprocess,resource,json
r=Path(__file__).resolve().parent
with(r/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','original','Main.hs'],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(300,300))
result=subprocess.run([str(r/'original')],capture_output=True,timeout=315,preexec_fn=bounded);assert result.returncode==0,result.stderr
assert result.stdout==(r/'last-piece.stdout').read_bytes();(r/'original.output').write_bytes(result.stdout)
(r/'dependency-versions.txt').write_text(subprocess.check_output(['ghc-pkg','field','containers','version,import-dirs'],text=True)+subprocess.check_output(['ghc-pkg','field','pretty','version,import-dirs'],text=True))
print('PASS complete original puzzle output:',len(result.stdout),'bytes',flush=True)
