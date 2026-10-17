from pathlib import Path
import csv,os,subprocess,tempfile,concurrent.futures
root=Path.cwd();suite=root/'examples/benchmarks';out=Path(tempfile.mkdtemp(prefix='bspt-mlkit-smoke-replay.',dir=root/'tests/out/benchmarks'))
print('VALIDATION OUTPUT',out,flush=True)
rows=[row for row in csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t')if row['benchmark']in{'bspt-lazy','bspt-strict'}and row['profile']in{'smoke','normal'}]
jobs=[(row,'hosts','native:mlkit')for row in rows if row['benchmark']=='bspt-lazy' and row['profile']=='smoke']
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
