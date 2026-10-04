from pathlib import Path
import csv,re,shutil
root=Path.cwd();suite=root/'examples/benchmarks';scratch=root/'tests/out/benchmarks';progress=scratch/'oct03-progress'
log=progress/'final-stack-ports.log';run=Path(re.search(r'VALIDATION OUTPUT (.+)',log.read_text())[1])
exclude=shutil.ignore_patterns('work','matrix','MLB','.cm','prog','program','runevm*','*.rbc','*.o','*.hi','*.exe','*.native')
for tag,names,count,reference,semantics in [('m5-stack',['stack_fold','stack_push_pop'],'stack','stack-originals',[])]:
    dest=suite/'results'/tag;dest.mkdir(exist_ok=True);shutil.copy(suite/'results/m4-rsa/.gitattributes',dest/'.gitattributes');shutil.copy(log,dest/'final-ports.log');records=[]
    for name in names:
        for profile in ['smoke','normal']:
            for level in ['O0','O2','hosts']:
                job=run/name/profile/level;verdict=(job/'result.log').read_text()
                assert 'PROGRAM FAIL ' not in verdict
                passes=[line.split()[-1].translate(str.maketrans(':@/','---'))for line in verdict.splitlines()if line.startswith('PROGRAM PASS ')]
                for cfg in sorted((job/'matrix').iterdir()):
                    if not cfg.is_dir()or not(cfg/'program').exists():continue
                    assert cfg.name in passes
                    opt='host-default'if level=='hosts'else level
                    saved=dest/'correctness-raw'/name/profile/opt/cfg.name;saved.mkdir(parents=True,exist_ok=True)
                    for filename in ['stdout','stderr','log','prog.key']:
                        if(cfg/'program'/filename).exists():shutil.copy(cfg/'program'/filename,saved/filename)
                    shutil.copy(job/'input',saved/'input');shutil.copy(job/'result.log',saved/'matrix.log')
                    records.append([name,profile,opt,cfg.name,(job/'input').read_text().splitlines()[1],'pass',str(saved.relative_to(suite))])
    assert len(records)==24*len(names),(tag,len(records))
    with(dest/'correctness.tsv').open('w')as f:
        w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(['benchmark','profile','optimization','configuration','arguments','status','artifact_directory']);w.writerows(records)
    countlog=progress/('count-'+count+'.log');shutil.copy(countlog,dest/'count.log');assert 'COUNT comparisons agree' in countlog.read_text()
    measurement=Path(re.search(r'BENCH MEASUREMENT (.+)',countlog.read_text())[1]);shutil.copytree(measurement,dest/'counts',ignore=exclude,dirs_exist_ok=True)
    refs=dest/'reference-observers';refs.mkdir(exist_ok=True)
    for file in(scratch/reference).iterdir():
        if file.suffix in ['.hs','.ml','.txt','.py']or file.name=='build.log':
            if file.name in ['benchmark.sml','semantics.sml','kernel.sml','observer.sml']:continue
            if file.name.endswith('.input'):continue
            shutil.copy(file,refs/file.name)
    for file in semantics:shutil.copy(scratch/reference/file,dest/file)
    print(tag,len(records),'cases archived')
