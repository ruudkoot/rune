from pathlib import Path
import csv,os,subprocess,tempfile
root=Path.cwd();suite=root/'examples/benchmarks';out=Path(tempfile.mkdtemp(prefix='final-stack.',dir=root/'tests/out/benchmarks'))
print('VALIDATION OUTPUT',out,flush=True)
selected={'stack_fold','stack_push_pop'}
rows=list(csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t'))
for row in rows:
    name=row['benchmark'];profile=row['profile']
    if name not in selected or profile not in ['smoke','normal']:continue
    for level,configs in [('O0','rune,rune:new,rune:jit,rune:opt'),('O2','rune,rune:new,rune:jit,rune:opt'),('hosts','native:mlton,native:smlnj-legacy,native:smlnj-dev,native:polyml')]:
        job=out/name/profile/level;job.mkdir(parents=True)
        (job/'sources.txt').write_text(''.join(str(suite/source)+'\n'for source in row['sources'].split(',')))
        (job/'input').write_text(name+'\n'+row['args']+'\n'+(suite/row['expected']).read_text().strip()+'\n')
        (job/'data-list').write_text('' if row['input_files']=='-' else '\n'.join(row['input_files'].split(','))+'\n')
        env=os.environ.copy();env.update(RUNE_BENCH_COMPILE_OPTIONS='-O0'if level=='O0'else'-O2',RUNE_MATRIX_TIMEOUT=row['timeout'],RUNE_MATRIX_MEMORY=row['memory_kib'])
        with(job/'result.log').open('w')as log:
            result=subprocess.run(['sh','tests/basis/run-matrix.sh','--configs',configs,'--program-list',str(job/'sources.txt'),'--program-input',str(job/'input'),'--program-data',str(suite/name),'--program-data-list',str(job/'data-list'),'--program-out',str(job/'matrix')],env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
        assert result.returncode==0,job
        print('PASS',name,profile,level,flush=True)
