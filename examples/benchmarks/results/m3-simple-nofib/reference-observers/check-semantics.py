from pathlib import Path
import subprocess,os,json
p=Path(__file__).resolve().parent;records=[]
for level in ['O0','O2']:
 env=os.environ.copy();env.update(RUNE_MATRIX_RUN=str(p/('worker-'+level)),RUNE_BENCH_COMPILE_OPTIONS='-'+level,RUNE_MATRIX_TIMEOUT='600',RUNE_MATRIX_MEMORY='1048576')
 with(p/('host-tests-'+level+'.log')).open('w')as log:r=subprocess.run(['sh','tests/basis/run-matrix.sh','--configs','rune,rune:new,rune:jit,rune:opt,native:mlton,native:smlnj-legacy,native:smlnj32,native:smlnj-dev,native:polyml,native:mlkit','--program-list',str(p/'sources.txt'),'--program-data',str(p/'data'),'--program-data-list',str(p/'data-list'),'--program-out',str(p/('host-tests-'+level))],env=env,stdout=log,stderr=subprocess.STDOUT)
 records.append(dict(level=level,exit=r.returncode));print(records[-1],flush=True)
(p/'semantic-exits.json').write_text(json.dumps(records,indent=2)+'\n')
raise SystemExit(1 if any(r['exit']for r in records)else 0)
