from pathlib import Path
import shutil,subprocess,json,time,resource
root=Path.cwd();p=root/'tests/out/benchmarks/bspt-originals';old=root/'tests/out/benchmarks/final-bspt-parallel.k_y6tynj/bspt-lazy/smoke/hosts/matrix/native-mlkit-4.7.23/program';d=p/'mlkit-compile-probe'
shutil.copytree(old,d,ignore=shutil.ignore_patterns('MLB','log','stdout','prog'),dirs_exist_ok=True)
f=d/'prog.mlb';f.write_text(f.read_text().replace(str(old),str(d)))
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
env=__import__('os').environ.copy();env['SML_LIB']='/home/ruud/.local/rune-hosts/mlkit/lib/mlkit'
t=time.monotonic()
with(p/'mlkit-compile-probe.log').open('w')as log:r=subprocess.run(['timeout','30','/home/ruud/.local/rune-hosts/mlkit/bin/mlkit','--no_messages','-o','prog','prog.mlb'],cwd=d,env=env,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap)
record=dict(exit_code=r.returncode,elapsed_seconds=time.monotonic()-t,timeout_seconds=30,memory_kib=1048576,executable_created=(d/'prog').exists())
(p/'mlkit-compile-probe.json').write_text(json.dumps(record,indent=2)+'\n');print(record)
