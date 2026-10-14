#!/usr/bin/env python3
"""Alternate complete compiler runs against hash-verified M1 artifacts.

Each compiler builds its own revision's fixed inputs and Basis. Output hashes
must match that revision's recorded outputs before timing ratios are accepted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import signal
import shlex
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--baseline-root', default='tests/out/intinf/baseline-tree')
parser.add_argument('--baseline-record', default='tests/intinf/baseline.json')
parser.add_argument('--vm-options',default='')
parser.add_argument('--baseline-options',default='')
parser.add_argument('--samples', type=int, default=15)
parser.add_argument('--current-record', help='reuse expected hashes from an existing run.py report')
parser.add_argument('--reference-compiler', default='bin/rune-mlton')
parser.add_argument('--out', default='tests/out/intinf/paired-compilers')
parser.add_argument('--workload', action='append', help='limit exploratory comparisons to a named workload')
args = parser.parse_args()
if args.samples < 2:
    parser.error('at least two samples are required')
os.chdir(ROOT)
base = Path(args.baseline_root).resolve()
out = Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)
record = json.loads((ROOT/args.baseline_record).read_text())
current = json.loads((ROOT/args.current_record).read_text()) if args.current_record else None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


for name in ('runevm','rune.rbc'):
    expected = next(value for path,value in record['tool_hashes'].items() if path.endswith('/'+name))
    if sha(base/'bin'/name) != expected:
        raise SystemExit('baseline '+name+' does not match the recorded baseline artifact')
environment = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
environment['LC_ALL'] = 'C'
report = {'baseline_options':args.baseline_options, 'samples':args.samples, 'warmup_pairs':2, 'vm_options':args.vm_options,
          'machine':platform.uname()._asdict(), 'affinity':sorted(os.sched_getaffinity(0)), 'load_start':os.getloadavg(),
          'baseline_record_sha256':sha(ROOT/args.baseline_record),
          'current_record_sha256':sha(ROOT/args.current_record) if args.current_record else None,
          'reference_compiler':args.reference_compiler,
          'compiler_hashes':{side:{name:sha(directory/'bin'/name)
                                 for name in ('runevm','rune.rbc')}
                             for side,directory in [('baseline',base),('current',ROOT)]},
          'baseline_revision':record['revision'],
          'current_revision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'workloads':{}}
for name,original in record['compiler_workloads'].items():
    if args.workload and name not in args.workload:
        continue
    if current:
        current_hash = current['compiler_workloads'][name]['output_sha256']
    else:
        reference = out/(name+'-reference.rbc')
        command = [str((ROOT/args.reference_compiler).resolve()), '--lib','lib',
                   '--target=registers','-o',str(reference),*original['inputs']]
        # Host-compiled Rune supplies the expected bytecode; this step is untimed.
        result = subprocess.run(command,check=True,capture_output=True,timeout=180)
        (out/(name+'-reference.command.json')).write_text(json.dumps(command)+'\n')
        (out/(name+'-reference.stderr')).write_bytes(result.stderr)
        current_hash = sha(reference)
    measurements = {'baseline':[], 'current':[]}
    cpu_measurements = {'baseline':[], 'current':[]}
    expected = {'baseline':original['output_sha256'],
                'current':current_hash}
    for i in range(args.samples+2):
        sides = ('baseline','current') if i % 2 else ('current','baseline')
        for side in sides:
            directory = base if side == 'baseline' else ROOT
            target = out/(name+'-'+side+'.rbc')
            target.unlink(missing_ok=True)
            command = [str(directory/'bin/runevm'),*(shlex.split(args.vm_options if side == 'current' else args.baseline_options)),'--heap-size','67108864',
                       str(directory/'bin/rune.rbc'),'--lib','lib','--target=registers',
                       '-o',str(target),*original['inputs']]
            def limits():
                resource.setrlimit(resource.RLIMIT_CORE,(0,0))
                resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
            started = time.perf_counter_ns()
            before_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            p = subprocess.Popen(command,cwd=directory,env=environment,
                                 stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                                 start_new_session=True,preexec_fn=limits)
            try:
                stdout,stderr = p.communicate(timeout=180)
            except BaseException:
                os.killpg(p.pid,signal.SIGKILL);p.communicate();raise
            seconds = (time.perf_counter_ns()-started)/1e9
            after_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            cpu_seconds = after_cpu.ru_utime + after_cpu.ru_stime - before_cpu.ru_utime - before_cpu.ru_stime
            prefix = out/(name+'-'+side+'-'+str(i))
            prefix.with_suffix('.stdout').write_bytes(stdout)
            prefix.with_suffix('.stderr').write_bytes(stderr)
            prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
            if p.returncode:
                raise RuntimeError(f'{name} {side}: exit {p.returncode}: {stderr.decode()}')
            actual = sha(target)
            if actual != expected[side]:
                raise RuntimeError(f'{name} {side}: output hash differs from its reference')
            if i >= 2:
                measurements[side].append(seconds)
                cpu_measurements[side].append(cpu_seconds)
    ratios = [c/b for c,b in zip(measurements['current'],measurements['baseline'])]
    report['workloads'][name] = {'runs':measurements, 'ratios':ratios,
        'cpu_runs':cpu_measurements,
        'median_cpu_ratio':statistics.median(c/b for c,b in zip(cpu_measurements['current'],cpu_measurements['baseline'])),
        'median_ratio':statistics.median(ratios), 'output_hashes':expected,
        'baseline_median':statistics.median(measurements['baseline']),
        'current_median':statistics.median(measurements['current'])}
    print(name, report['workloads'][name]['median_ratio'],flush=True)
    report['load_end'] = os.getloadavg()
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
