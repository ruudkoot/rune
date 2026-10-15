#!/usr/bin/env python3
"""Compare changed arithmetic paths against retained bytecodes of the same sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--baseline-run', required=True, help='run.py or dispatch.py output with sources and bytecodes')
p.add_argument('--baseline-vm', required=True)
p.add_argument('--samples', type=int, default=25)
p.add_argument('--workload', action='append')
p.add_argument('--mode', action='append', choices=['gmp', 'sml'])
p.add_argument('--out', required=True)
a = p.parse_args()
if a.samples < 2: p.error('at least two measured pairs are required')
os.chdir(ROOT)
base = Path(a.baseline_run).resolve()
out = Path(a.out).resolve()
if out.exists(): p.error('use a fresh output directory')
out.mkdir(parents=True)
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
reference = json.loads((base/'report.json').read_text())
expected_vm = reference.get('vm_sha256') or next(h for n,h in reference['tool_hashes'].items() if n.endswith('/runevm'))
assert sha(a.baseline_vm) == expected_vm, 'baseline VM differs from its recorded artifact'
names = a.workload or list(reference['workloads'])
if set(names)-reference['workloads'].keys(): p.error('unknown workload')
env = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
env['LC_ALL'] = 'C'
report = {'description': __doc__, 'samples': a.samples, 'warmup_pairs': 2,
          'affinity': sorted(os.sched_getaffinity(0)), 'load_start': os.getloadavg(),
          'driver_sha256': sha(__file__), 'baseline_record_sha256': sha(base/'report.json'),
          'baseline_vm_sha256': sha(a.baseline_vm), 'vm_sha256': sha('bin/runevm'),
          'compiler_sha256': sha('bin/rune.rbc'), 'intinf_sha256': sha('lib/basis/intinf.sml'), 'workloads': {}}
sequence = 0

def run(command):
    global sequence
    sequence += 1
    command = list(map(str,command))
    prefix = out/f'{sequence:05d}'
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    child = subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                             start_new_session=True,preexec_fn=limits)
    try: stdout,stderr = child.communicate(timeout=180)
    except BaseException:
        try: os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError: pass
        stdout,stderr = child.communicate()
        prefix.with_suffix('.stdout').write_bytes(stdout)
        prefix.with_suffix('.stderr').write_bytes(stderr)
        prefix.with_suffix('.status').write_text('timeout/interruption\n')
        raise
    prefix.with_suffix('.stdout').write_bytes(stdout)
    prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(child.returncode)+'\n')
    assert child.returncode == 0, (command,stderr.decode())
    return stdout.decode(),stderr.decode()

for name in names:
    w = reference['workloads'][name]
    source = base/(name+'.sml')
    assert sha(source) == w['source_sha256'], name
    program = out/(name+'.rbc')
    run(['bin/rune','--lib','lib','-o',program,source])
    entry = {'source_sha256':sha(source),'bytecode_sha256':{'baseline':sha(base/(name+'.rbc')),'current':sha(program)},'modes':{}}
    report['workloads'][name] = entry
    for mode in a.mode or ['gmp','sml']:
        runs = {'baseline':[],'current':[]}
        commands = {'baseline':[a.baseline_vm,'--intinf='+mode,base/(name+'.rbc')],
                    'current':['bin/runevm','--intinf='+mode,program]}
        for i in range(a.samples+2):
            for side in (['baseline','current'] if i%2 else ['current','baseline']):
                stdout,_ = run(commands[side])
                timing,answer = stdout.split('\n',1)
                assert timing.startswith('TIMING ') and answer == w['expected'], (name,side,stdout)
                if i >= 2: runs[side].append(float(timing[7:]))
        stats = {}
        for side,command in commands.items():
            stdout,stats[side] = run([command[0],'--count','--stats','--intinf-stats',*command[1:]])
            assert stdout.split('\n',1)[1] == w['expected']
        ratios = [x/y for x,y in zip(runs['current'],runs['baseline'])]
        entry['modes'][mode] = {'runs':runs,'ratios':ratios,'median_ratio':statistics.median(ratios),'stats':stats}
        report['load_end'] = os.getloadavg()
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(name,mode,statistics.median(ratios),flush=True)
