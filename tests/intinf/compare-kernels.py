#!/usr/bin/env python3
"""Pair fixed arithmetic bytecodes across accepted implementation revisions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import signal
import statistics
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser()
p.add_argument('--baseline-vm',default='tests/out/intinf/m2-tree/bin/runevm')
p.add_argument('--baseline-run',default='tests/out/intinf/m2-final4')
p.add_argument('--current-run',required=True)
p.add_argument('--vm',default='bin/runevm')
p.add_argument('--vm-options',default='--intinf=gmp')
p.add_argument('--baseline-options',default='')
p.add_argument('--group',default='small')
p.add_argument('--samples',type=int,default=25)
p.add_argument('--out',required=True)
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
base=Path(a.baseline_run).resolve();current=Path(a.current_run).resolve()
b=json.loads((base/'report.json').read_text());c=json.loads((current/'report.json').read_text())
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
expected=next(v for k,v in b['tool_hashes'].items() if k.endswith('/runevm'))
assert sha(a.baseline_vm)==expected,'baseline VM differs from the recorded binary'
report={'samples':a.samples,'warmup_pairs':2,'affinity':sorted(os.sched_getaffinity(0)),'load_start':os.getloadavg(),
        'baseline_record_sha256':sha(base/'report.json'),'current_record_sha256':sha(current/'report.json'),
        'baseline_options':a.baseline_options,'vm_sha256':sha(a.vm),'baseline_vm_sha256':sha(a.baseline_vm),'vm_options':a.vm_options,'workloads':{}}
for name,entry in b['workloads'].items():
    if entry['group']!=a.group:continue
    assert entry['source_sha256']==c['workloads'][name]['source_sha256']
    measurements={'baseline':[],'current':[]}
    for i in range(a.samples+2):
        for side in (['baseline','current'] if i%2 else ['current','baseline']):
            directory,vm,flags=(base,a.baseline_vm,shlex.split(a.baseline_options)) if side=='baseline' else (current,a.vm,shlex.split(a.vm_options))
            command=[vm,*flags,str(directory/(name+'.rbc'))]
            prefix=out/(name+'-'+side+'-'+str(i))
            def limits():
                resource.setrlimit(resource.RLIMIT_CORE,(0,0));resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
            child=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,preexec_fn=limits,start_new_session=True)
            try:stdout,stderr=child.communicate(timeout=180)
            except BaseException:
                try:os.killpg(child.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                child.communicate();raise
            prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
            prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
            assert child.returncode==0,stderr
            timing,answer=stdout.decode().split('\n',1)
            assert answer==entry['expected'] and timing.startswith('TIMING '),(name,stdout)
            if i>=2:measurements[side].append(float(timing[7:]))
    ratios=[x/y for x,y in zip(measurements['current'],measurements['baseline'])]
    report['workloads'][name]={'runs':measurements,'ratios':ratios,'median_ratio':statistics.median(ratios)}
    print(name,statistics.median(ratios),flush=True)
    report['load_end']=os.getloadavg()
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
