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
import run as corpus

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--samples',type=int,default=7);p.add_argument('--out',default='tests/out/intinf/dispatch')
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
seq=0

def execute(command):
    global seq
    seq+=1;command=list(map(str,command));prefix=out/f'{seq:03d}'
    def limit():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0));resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    child=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,preexec_fn=limit)
    try:stdout,stderr=child.communicate(timeout=180)
    except BaseException:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        child.communicate();raise
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
    assert child.returncode==0,stderr.decode()
    return stdout.decode()

shapes={'add':[(63,63),(128,128),(512,512),(4096,4096)],
        'mul':[(31,33),(63,63),(128,128),(512,512),(4096,128)],
        'div':[(31,65),(128,256),(128,64),(512,256),(4096,2048)],
        'bits':[(63,63),(128,128),(512,512),(4096,4096)]}
report={'description':'Exploratory dispatch sweep, independent of the fixed acceptance corpus',
        'samples':a.samples,'warmup_pairs':1,'affinity':sorted(os.sched_getaffinity(0)),'load_start':os.getloadavg(),'workloads':{}}
report['vm_sha256']=hashlib.sha256(Path('bin/runevm').read_bytes()).hexdigest()
report['compiler_sha256']=hashlib.sha256(Path('bin/rune.rbc').read_bytes()).hexdigest()
report['source_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path('runtime/intinf.c'),Path('lib/basis/intinf.sml')]}
for op,operands in shapes.items():
    for bits,other in operands:
        n=max(1000,100000//max(1,bits//64))
        if op=='mul':n=max(300,n//max(1,other//64))
        name=f'{op}-{bits}-{other}'
        w={'bits':bits,'other_bits':other,'op':op,'iterations':n}
        source,expected=corpus.workload(w)
        path=out/(name+'.sml');path.write_text(source);rbc=path.with_suffix('.rbc')
        execute(['bin/rune','-o',rbc,path])
        runs={'gmp':[],'sml':[]}
        for i in range(a.samples+1):
            for mode in (['gmp','sml'] if i%2 else ['sml','gmp']):
                stdout=execute(['bin/runevm','--intinf='+mode,rbc]);timing,answer=stdout.split('\n',1)
                assert answer==expected and timing.startswith('TIMING ')
                if i:runs[mode].append(float(timing[7:]))
        speed=statistics.median(s/g for s,g in zip(runs['sml'],runs['gmp']))
        report['workloads'][name]={**w,'runs':runs,'paired_speedup':speed,'expected':expected,
            'source_sha256':hashlib.sha256(source.encode()).hexdigest()}
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(name,round(speed,3),flush=True)
