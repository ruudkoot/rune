#!/usr/bin/env python3
"""Exploratory operation/shape sweep; never substitutes for workloads.json."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import statistics
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--samples',type=int,default=7);p.add_argument('--out',default='tests/out/intinf/dispatch')
p.add_argument('--baseline-root',help='also compare the same operands with this compiler and VM')
p.add_argument('--workload',action='append',help='repeat only a named operation/shape case')
p.add_argument('--reuse-run',help='repeat a hash-verified run without rebuilding its bytecodes')
a=p.parse_args();os.chdir(ROOT)
if a.samples < 2:p.error('at least two measured pairs are required')
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
seq=0

def execute(command,cwd=ROOT):
    global seq
    seq+=1;command=list(map(str,command));prefix=out/f'{seq:03d}'
    def limit():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0));resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    child=subprocess.Popen(command,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,preexec_fn=limit)
    try:stdout,stderr=child.communicate(timeout=180)
    except BaseException:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        child.communicate();raise
    prefix.with_suffix('.command.json').write_text(json.dumps({'argv':command,'cwd':str(cwd)})+'\n')
    prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
    assert child.returncode==0,stderr.decode()
    return stdout.decode()

shapes={'add':[(63,63),(128,128),(512,512),(4096,4096)],
        'mul':[(31,33),(63,63),(128,128),(512,512),(4096,128)],
        'div':[(31,65),(128,256),(128,64),(512,256),(4096,2048)],
        'bits':[(63,63),(128,128),(512,512),(4096,4096)]}
names={f'{op}-{bits}-{other}' for op,pairs in shapes.items() for bits,other in pairs}
if a.workload and set(a.workload)-names:p.error('unknown workload: '+', '.join(sorted(set(a.workload)-names)))
report={'description':'Exploratory dispatch sweep, independent of the fixed acceptance corpus',
        'driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'samples':a.samples,'warmup_pairs':1,'affinity':sorted(os.sched_getaffinity(0)),'load_start':os.getloadavg(),'workloads':{}}
baseline=Path(a.baseline_root).resolve() if a.baseline_root else None
if baseline:
    report['baseline']={'root':str(baseline),'vm_sha256':hashlib.sha256((baseline/'bin/runevm').read_bytes()).hexdigest(),'compiler_sha256':hashlib.sha256((baseline/'bin/rune.rbc').read_bytes()).hexdigest()}
report['vm_sha256']=hashlib.sha256(Path('bin/runevm').read_bytes()).hexdigest()
report['compiler_sha256']=hashlib.sha256(Path('bin/rune.rbc').read_bytes()).hexdigest()
report['source_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path('runtime/intinf.c'),Path('lib/basis/intinf.sml')]}
reuse=Path(a.reuse_run).resolve() if a.reuse_run else None
if reuse:
    original=json.loads((reuse/'report.json').read_text())
    for key in ['vm_sha256','compiler_sha256','source_hashes']:
        assert original[key]==report[key],('changed reuse input',key)
    assert original.get('baseline')==report.get('baseline'),'changed reuse baseline'
    report['reused_report_sha256']=hashlib.sha256((reuse/'report.json').read_bytes()).hexdigest()
for op,operands in shapes.items():
    for bits,other in operands:
        n=max(1000,100000//max(1,bits//64))
        if op=='mul':n=max(300,n//max(1,other//64))
        name=f'{op}-{bits}-{other}'
        if a.workload and name not in a.workload:continue
        w={'bits':bits,'other_bits':other,'op':op,'iterations':n}
        source,expected=json.loads(subprocess.check_output(['bin/rune-intinf','workload','--spec',json.dumps(w)],text=True))
        path=(reuse or out)/(name+'.sml');rbc=path.with_suffix('.rbc')
        if reuse:
            assert hashlib.sha256(path.read_bytes()).hexdigest()==hashlib.sha256(source.encode()).hexdigest()
            assert hashlib.sha256(rbc.read_bytes()).hexdigest()==original['workloads'][name]['bytecode_sha256']['current']
        else:
            path.write_text(source)
            execute(['bin/rune','--lib','lib','-o',rbc,path])
        runs={'gmp':[],'sml':[]}
        if baseline:
            old=(reuse or out)/(name+'-baseline.rbc')
            if reuse:
                assert hashlib.sha256(old.read_bytes()).hexdigest()==original['workloads'][name]['bytecode_sha256']['baseline']
            else:execute([baseline/'bin/rune','--lib','lib','-o',old,path],baseline)
            runs['baseline']=[]
        for i in range(a.samples+1):
            order=list(runs)
            for mode in (order if i%2 else list(reversed(order))):
                command=[baseline/'bin/runevm',old] if mode=='baseline' else ['bin/runevm','--intinf='+mode,rbc]
                stdout=execute(command);timing,answer=stdout.split('\n',1)
                assert answer==expected and timing.startswith('TIMING ')
                if i:runs[mode].append(float(timing[7:]))
        speed=statistics.median(s/g for s,g in zip(runs['sml'],runs['gmp']))
        report['workloads'][name]={**w,'runs':runs,'paired_speedup':speed,'expected':expected,
            'source_sha256':hashlib.sha256(source.encode()).hexdigest(),
            'bytecode_sha256':{'current':hashlib.sha256(rbc.read_bytes()).hexdigest()}}
        if baseline:
            report['workloads'][name]['bytecode_sha256']['baseline']=hashlib.sha256(old.read_bytes()).hexdigest()
            report['workloads'][name]['ratios_to_baseline']={mode:statistics.median(t/b for t,b in zip(runs[mode],runs['baseline'])) for mode in ['gmp','sml']}
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(name,round(speed,3),flush=True)
