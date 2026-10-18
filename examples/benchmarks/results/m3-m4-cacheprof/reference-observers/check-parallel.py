from pathlib import Path
import csv,os,subprocess,tempfile,concurrent.futures
root=Path.cwd();suite=root/'examples/benchmarks';out=Path(tempfile.mkdtemp(prefix='final-cacheprof-parallel.',dir=root/'tests/out/benchmarks'))
print('VALIDATION OUTPUT',out,flush=True)
rows=[row for row in csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t')if row['benchmark']in{'cacheprof-strict', 'cacheprof-nofib-strict', 'cacheprof-lazy', 'cacheprof-nofib-lazy'}and row['profile']in{'smoke','normal'}]
jobs=[(row,level,configs)for row in rows for level,configs in [('O0','rune,rune:new,rune:jit,rune:opt'),('O2','rune,rune:new,rune:jit,rune:opt'),('hosts','native:mlton,native:smlnj-legacy,native:smlnj32,native:smlnj-dev,native:polyml,native:mlkit')]]
def run(job_spec):
 row,level,configs=job_spec;name=row['benchmark'];profile=row['profile'];job=out/name/profile/level;job.mkdir(parents=True)
 (job/'sources.txt').write_text(''.join(str(suite/source)+'\n'for source in row['sources'].split(',')))
 (job/'input').write_text(name+'\n'+row['args']+'\n'+(suite/row['expected']).read_text().strip()+'\n')
 (job/'data-list').write_text('' if row['input_files']=='-' else '\n'.join(row['input_files'].split(','))+'\n')
 env=os.environ.copy();env.update(RUNE_BENCH_COMPILE_OPTIONS='-O0'if level=='O0'else'-O2',RUNE_MATRIX_TIMEOUT=row['timeout'],RUNE_MATRIX_MEMORY=row['memory_kib'],RUNE_MATRIX_RUN=str(job/'worker'))
 with(job/'result.log').open('w')as log:result=subprocess.run(['sh','tests/basis/run-matrix.sh','--configs',configs,'--program-list',str(job/'sources.txt'),'--program-input',str(job/'input'),'--program-data',str(suite/name),'--program-data-list',str(job/'data-list'),'--program-out',str(job/'matrix')],env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
 print('FAIL'if result.returncode else'PASS',name,profile,level,flush=True);return result.returncode
with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:statuses=list(pool.map(run,jobs))
raise SystemExit(1 if any(statuses)else 0)
