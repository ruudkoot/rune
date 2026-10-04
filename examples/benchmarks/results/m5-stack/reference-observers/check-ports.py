from pathlib import Path
import json,os,subprocess,tempfile
root=Path.cwd();reference=root/'tests/out/benchmarks/stack-originals';out=Path(tempfile.mkdtemp(prefix='stack-ports.',dir=root/'tests/out/benchmarks'))
print('VALIDATION OUTPUT',out,flush=True)
profiles={}
for name,normal,multiplier in [('stack_fold',2500000,5050),('stack_push_pop',100000000,1)]:
    cases={}
    for profile,n in [('smoke',100),('normal',normal)]:
        cases[profile]=[str(n),str(n*multiplier)]
        for level,configs in [('O0','rune,rune:new,rune:jit,rune:opt'),('O2','rune,rune:new,rune:jit,rune:opt'),('hosts','native:mlton,native:smlnj-legacy,native:smlnj-dev,native:polyml')]:
            job=out/name/profile/level;job.mkdir(parents=True)
            files=[root/'examples/benchmarks/shared/input.sml',reference/'kernel.sml',reference/(name+'.sml'),root/'examples/benchmarks/shared/main.sml']
            (job/'sources.txt').write_text(''.join(str(f)+'\n'for f in files));(job/'input').write_text(f'{name}\n{n}\n{n*multiplier}\n')
            env=os.environ.copy();env.update(RUNE_BENCH_COMPILE_OPTIONS='-O0'if level=='O0'else'-O2',RUNE_MATRIX_TIMEOUT='30'if profile=='smoke'else'600',RUNE_MATRIX_MEMORY='1048576'if profile=='smoke'else'4194304')
            with(job/'result.log').open('w')as log:
                result=subprocess.run(['sh','tests/basis/run-matrix.sh','--configs',configs,'--program-list',str(job/'sources.txt'),'--program-input',str(job/'input'),'--program-out',str(job/'matrix')],env=env,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
            assert result.returncode==0,job
            print('PASS',name,profile,level,flush=True)
    profiles[name]=cases
(reference/'profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
