from pathlib import Path
import subprocess,shutil,json
root=Path.cwd();p=root/'tests/out/benchmarks/sauvola-originals'
source=root/'tests/out/benchmarks/final-sandmark-applications-parallel.yhp40qqz/contrast/normal/hosts/matrix/native-smlnj-legacy-110.99.9/program'
out=p/'legacy-normal-diagnostics';out.mkdir(exist_ok=True)
records=[]
for mode,args in [('default',[]),('nursery64m',['@SMLalloc=64m'])]:
 for i in range(1,4):
  dest=out/(mode+'-'+str(i));shutil.copytree(source,dest,dirs_exist_ok=True)
  command=['/home/ruud/.local/rune-hosts/smlnj-legacy/bin/sml']+args+['driver.sml']
  with(source.parents[2]/'input').open('rb')as inp,(dest/'replay.stdout').open('wb')as stdout,(dest/'replay.stderr').open('wb')as stderr:
   result=subprocess.run(command,cwd=dest,stdin=inp,stdout=stdout,stderr=stderr,timeout=120)
  data=(dest/'replay.stdout').read_text();passed=result.returncode==0 and 'SUMMARY 1 checks, 0 failed'in data
  records.append(dict(mode=mode,run=i,exit=result.returncode,pass_check=passed,command=command))
  print(mode,i,'PASS'if passed else'FAIL',flush=True)
(out/'results.json').write_text(json.dumps(records,indent=2)+'\n')
