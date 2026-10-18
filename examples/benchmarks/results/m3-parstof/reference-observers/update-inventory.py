from pathlib import Path
import subprocess
root=Path.cwd();p=Path(__file__).resolve().parent
f=root/'scripts/benchmark-inventory.py';t=f.read_text();old='    if key == "lift":\n';assert old in t;f.write_text(t.replace(old,'    if key in {"lift", "parstof"}:\n'))
args=['python3','scripts/benchmark-inventory.py']
for name,path in [('mlton','pinned/mlton'),('smlnj','pinned/smlnj'),('mlkit','pinned/mlkit'),('nofib','pinned/nofib'),('sandmark','upstreams/sandmark')]:args+=['--source',name+'='+str(root/'tests/out/benchmarks'/path)]
with(p/'inventory-tests.log').open('w')as log:subprocess.run(['python3','tests/benchmarks/test-inventory.py'],stdout=log,stderr=subprocess.STDOUT,check=True)
for mode in ['write','check']:
 with(p/('inventory-'+mode+'.log')).open('w')as log:subprocess.run(args+['--'+mode],stdout=log,stderr=subprocess.STDOUT,check=True)
