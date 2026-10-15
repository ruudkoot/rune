#!/usr/bin/env python3
"""Measure runtime backend selection against constant-selection experiments.

These test-only Basis copies retain packed values, limits, normalization and
GMP import/export. They cannot test the cost of that representation against
persistent GMP objects, and must not be used as deployable replacements.
Compiler controls compile the same normal input library so output hashes agree;
they do not remove the cost of parsing the fallback source definitions.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import re
import shutil
import signal
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--run', required=True, help='normal run.py corpus and report')
p.add_argument('--out', required=True)
p.add_argument('--samples', type=int, default=25)
p.add_argument('--compiler-samples', type=int, default=25)
a = p.parse_args()
if min(a.samples, a.compiler_samples) < 2:
    p.error('at least two measured pairs are required')
os.chdir(ROOT)
out = Path(a.out).resolve()
if out.exists():
    p.error('use a fresh output directory to preserve earlier experiments')
out.mkdir(parents=True)
normal = Path(a.run).resolve()
reference = json.loads((normal/'report.json').read_text())
sha = lambda f: hashlib.sha256(Path(f).read_bytes()).hexdigest()
assert sha('bin/runevm') == next(v for k,v in reference['tool_hashes'].items() if k.endswith('/runevm'))
env = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
seq = 0
primitive_names = [line.split()[0] for line in Path('runtime/prims.def').read_text().splitlines() if line.strip() and not line.startswith('#')]
capability_primitive = primitive_names.index('intinf_gmp_available')
capability_opcode = re.compile(r'\bPRIM(?:PUSH)?\s+'+str(capability_primitive)+r'\b')
report = {'description': __doc__, 'revision': subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'driver_sha256': sha(__file__), 'normal_report_sha256': sha(normal/'report.json'), 'vm_sha256': sha('bin/runevm'),
          'compiler_sha256': sha('bin/rune.rbc'), 'samples': a.samples, 'compiler_samples': a.compiler_samples,
          'warmup_pairs': 2, 'affinity': sorted(os.sched_getaffinity(0)), 'load_start': os.getloadavg(), 'modes': {}}


def run(command, label, cwd=ROOT):
    global seq
    seq += 1
    command = list(map(str, command))
    prefix = out/f'{seq:05d}-{label}'
    prefix.with_suffix('.command.json').write_text(json.dumps({'argv':command,'cwd':str(cwd)})+'\n')
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE, (0,0))
        resource.setrlimit(resource.RLIMIT_AS, (4*1024**3, 4*1024**3))
    start = time.perf_counter_ns()
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    child = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             start_new_session=True, preexec_fn=limits)
    try:
        stdout, stderr = child.communicate(timeout=180)
    except BaseException:
        try: os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        stdout, stderr = child.communicate()
        prefix.with_suffix('.stdout').write_bytes(stdout)
        prefix.with_suffix('.stderr').write_bytes(stderr)
        prefix.with_suffix('.status').write_text('timeout/interruption\n')
        raise
    elapsed = (time.perf_counter_ns()-start)/1e9
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    prefix.with_suffix('.stdout').write_bytes(stdout)
    prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(child.returncode)+'\n')
    assert child.returncode == 0, (command, child.returncode, stderr.decode())
    return stdout.decode(), stderr.decode(), {'wall': elapsed,
        'cpu': after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime}


def save():
    report['load_end'] = os.getloadavg()
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')


for mode,constant in [('gmp','true'),('sml','false')]:
    directory = out/mode
    library = directory/'lib'
    shutil.copytree(ROOT/'lib', library)
    basis = library/'basis/intinf.sml'
    old = '  val gmpAvailable = _prim "intinf_gmp_available" : unit -> bool'
    text = basis.read_text()
    assert text.count(old) == 1
    basis.write_text(text.replace(old, '  fun gmpAvailable () = '+constant))
    # Keep logical source paths identical: only the capability binding changes.
    (directory/'src').symlink_to(ROOT/'src', target_is_directory=True)
    (directory/'build').mkdir()
    shutil.copyfile(ROOT/'build/config.sml',directory/'build/config.sml')
    entry = {'changed_line': {'from': old, 'to': '  fun gmpAvailable () = '+constant},
             'experimental_intinf_sha256': sha(basis), 'workloads': {}, 'compilers': {}}
    report['modes'][mode] = entry
    # Exact-answer corpus on the specialized implementation before timing it.
    checks = directory/'checks.rbc'
    run([ROOT/'bin/rune','--lib','lib','-o',checks,ROOT/'tests/intinf/oracle.sml',normal/'vectors.sml',ROOT/'tests/intinf/checks.sml'],mode+'-checks-compile',directory)
    stdout,_,_ = run(['bin/runevm','--intinf='+mode,checks],mode+'-checks')
    assert stdout == 'current: 1154 checks\noracle: 1154 checks\n', stdout
    for name,w in reference['workloads'].items():
        program = directory/(name+'.rbc')
        run([ROOT/'bin/rune','--lib','lib','-o',program,normal/(name+'.sml')],mode+'-'+name+'-compile',directory)
        disassembly = {}
        for side,rbc in [('normal',normal/(name+'.rbc')),('specialized',program)]:
            text,_,_ = run(['bin/runevm','--disasm',rbc],mode+'-'+name+'-'+side+'-disasm')
            disassembly[side] = {'sha256': hashlib.sha256(text.encode()).hexdigest(),
                'capability_queries': len(capability_opcode.findall(text))}
        assert disassembly['specialized']['capability_queries'] == 0, 'specialization retained a capability query'
        values = {'normal': [], 'specialized': []}
        for i in range(a.samples+2):
            for side in (['normal','specialized'] if i%2 else ['specialized','normal']):
                rbc = normal/(name+'.rbc') if side == 'normal' else program
                stdout,_,usage = run(['bin/runevm','--intinf='+mode,rbc],mode+'-'+name+'-'+side)
                timing,answer = stdout.split('\n',1)
                assert timing.startswith('TIMING ') and answer == w['expected'], (name,stdout)
                if i >= 2: values[side].append({**usage, 'kernel': float(timing[7:])})
        ratios = [n['kernel']/s['kernel'] for n,s in zip(values['normal'],values['specialized'])]
        stats = {}
        for side,rbc in [('normal',normal/(name+'.rbc')),('specialized',program)]:
            _,stats[side],_ = run(['bin/runevm','--intinf='+mode,'--count','--stats','--intinf-stats',rbc],mode+'-'+name+'-'+side+'-stats')
        entry['workloads'][name] = {'runs': values, 'normal_over_specialized_ratios': ratios,
            'median_ratio': statistics.median(ratios), 'stats': stats, 'disassembly': disassembly,
            'bytecode_bytes': {'normal': (normal/(name+'.rbc')).stat().st_size, 'specialized': program.stat().st_size},
            'bytecode_sha256': {'normal': sha(normal/(name+'.rbc')), 'specialized': sha(program)}}
        save()
        print(mode,name,statistics.median(ratios),flush=True)
    compiler = directory/'compiler.rbc'
    inputs = reference['compiler_workloads']['bootstrap']['inputs']
    run([ROOT/'bin/rune','--lib','lib','--target=registers','-o',compiler,*inputs],mode+'-compiler-build',directory)
    entry['compiler_bytes'] = {'normal': Path('bin/rune.rbc').stat().st_size, 'specialized': compiler.stat().st_size}
    entry['compiler_sha256'] = sha(compiler)
    for name,w in reference['compiler_workloads'].items():
        values = {'normal': [], 'specialized': []}
        for i in range(a.compiler_samples+2):
            for side in (['normal','specialized'] if i%2 else ['specialized','normal']):
                result = directory/(name+'-'+side+'.rbc')
                result.unlink(missing_ok=True)
                _,_,usage = run(['bin/runevm','--intinf='+mode,'--heap-size','67108864',
                    'bin/rune.rbc' if side == 'normal' else compiler,'--lib','lib','--target=registers',
                    '-o',result,*w['inputs']],mode+'-'+name+'-'+side)
                assert sha(result) == w['output_sha256'], (mode,name,side)
                if i >= 2: values[side].append(usage)
        ratios = [n['wall']/s['wall'] for n,s in zip(values['normal'],values['specialized'])]
        entry['compilers'][name] = {'runs': values, 'normal_over_specialized_ratios': ratios,
                                    'median_ratio': statistics.median(ratios)}
        save()
        print(mode,name,statistics.median(ratios),flush=True)
# An ordinary Int control quantifies the small-value representation cost.
# The fixed operands fit Int; this control does not offer IntInf semantics.
report['machine_int'] = {}
for name,w in reference['workloads'].items():
    if w['group'] != 'small':
        continue
    source = out/(name+'-machine-int.sml')
    text = (normal/(name+'.sml')).read_text()
    assert text.count('structure I = IntInf\n') == 1
    source.write_text(text.replace('structure I = IntInf\n','structure I = Int\n'))
    program = source.with_suffix('.rbc')
    run(['bin/rune','--lib','lib','-o',program,source],name+'-machine-int-compile')
    values = {'intinf': [], 'int': []}
    for i in range(a.samples+2):
        for side in (['intinf','int'] if i%2 else ['int','intinf']):
            rbc = normal/(name+'.rbc') if side == 'intinf' else program
            stdout,_,usage = run(['bin/runevm','--intinf=gmp',rbc],name+'-'+side)
            timing,answer = stdout.split('\n',1)
            assert timing.startswith('TIMING ') and answer == w['expected'], (name,stdout)
            if i >= 2: values[side].append({**usage,'kernel':float(timing[7:])})
    ratios = [n['kernel']/i['kernel'] for n,i in zip(values['intinf'],values['int'])]
    stats = {}
    for side,rbc in [('intinf',normal/(name+'.rbc')),('int',program)]:
        _,stats[side],_ = run(['bin/runevm','--intinf=gmp','--count','--stats',rbc],name+'-'+side+'-stats')
    report['machine_int'][name] = {'runs':values,'intinf_over_int_ratios':ratios,
        'median_ratio':statistics.median(ratios),'stats':stats,
        'limitation':'Finite-precision Int on these bounded operands; not a replacement for IntInf.'}
    save()
    print('machine-int',name,statistics.median(ratios),flush=True)
report['result'] = 'pass'
save()
