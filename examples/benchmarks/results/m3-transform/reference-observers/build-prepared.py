from pathlib import Path
import subprocess
root=Path.cwd();p=Path(__file__).resolve().parent
parts=['types.sml','compare.sml','structure.sml','label.sml','print.sml','serialize.sml','parsed-cases.sml']
(p/'prepared-check.sml').write_text(''.join((p/f).read_text()for f in parts)+'end\n')
files=[root/'examples/benchmarks/shared/lazy.sml',root/'examples/benchmarks/shared/suspend.sml',root/'examples/benchmarks/shared/hartel-ida-finite.sml',p/'prepared-check.sml',p/'prepared-pilot.sml']
with(p/'prepared-build.log').open('w')as log:subprocess.run(['bin/rune','--lint',*map(str,files),'-o',str(p/'prepared.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'prepared.log').open('w')as log:subprocess.run([str(root/'bin/runevm'),'prepared.rbc'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
print((p/'prepared.log').read_text())
