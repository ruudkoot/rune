from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent
template=p/'host-profile-diagnostics/native-smlnj-legacy-110.99.9/program'
out=p/'nursery-diagnostics';out.mkdir(exist_ok=True)
results=[]
for mode,options in [('default',[]),('nursery64m',['@SMLalloc=64m'])]:
 for i in range(1,6):
  d=out/(mode+'-'+str(i));d.mkdir(exist_ok=True)
  for name in ['driver.sml','smoke.reference']:shutil.copy(template/name,d/name)
  command=['/home/ruud/.local/rune-hosts/smlnj-legacy/bin/sml']+options
  with(d/'driver.sml').open('rb')as inp,(d/'stdout').open('wb')as stdout,(d/'stderr').open('wb')as stderr:
   result=subprocess.run(command,cwd=d,stdin=inp,stdout=stdout,stderr=stderr,timeout=120)
  passed=result.returncode==0 and 'SUMMARY 1 checks, 0 failed'in(d/'stdout').read_text()
  results.append(dict(mode=mode,run=i,exit=result.returncode,passed=passed,command=command))
  print(mode,i,'PASS'if passed else'FAIL',flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
