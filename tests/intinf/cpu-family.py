#!/usr/bin/env python3
"""Exercise the fat x86-64 package on baseline and named emulated CPUs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser()
p.add_argument('--vm',default='bin/runevm')
p.add_argument('--out',default='tests/out/intinf/cpu-family')
p.add_argument('--cpu',action='append')
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
report={'vm_sha256':hashlib.sha256(Path(a.vm).read_bytes()).hexdigest(),
        'qemu':subprocess.check_output(['qemu-x86_64','--version'],text=True).splitlines()[0],
        'runs':{},'result':'running'}
subprocess.run(['python3','tests/intinf/run.py','--vm','bin/runevm-sml','--vm-options=--intinf=sml',
                '--out',str(out/'semantic')],check=True,env=env,timeout=180)
program=out/'semantic/checks.rbc'
counts=set()
for cpu in a.cpu or ['qemu64','Conroe','Opteron_G1','max']:
    for tier,options in [('off',['--jit=off']),('1',['--jit=all','--jit-tier=1']),('2',['--jit=all','--jit-tier=2'])]:
        command=['qemu-x86_64','-cpu',cpu,a.vm,'--intinf=gmp','--count','--intinf-stats',*options,str(program)]
        def limits():resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        child=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                               start_new_session=True,preexec_fn=limits)
        try:stdout,stderr=child.communicate(timeout=180)
        except BaseException:
            try:os.killpg(child.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            child.communicate();raise
        key=cpu+'-'+tier
        report['runs'][key]={'command':command,'exit':child.returncode,'stdout':stdout.decode(),'stderr':stderr.decode()}
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        assert child.returncode==0 and stdout==b'current: 1154 checks\noracle: 1154 checks\n',(key,stderr.decode())
        assert b'0 GMP live' in stderr
        counts.add(re.search(rb'runevm: count: ([^\n]+)',stderr).group(1).decode())
        print(cpu,tier,'passes',flush=True)
assert len(counts)==1,counts
report.update(result='pass',counts=list(counts),bytecode_sha256=hashlib.sha256(program.read_bytes()).hexdigest())
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
