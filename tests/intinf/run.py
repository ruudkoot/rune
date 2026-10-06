#!/usr/bin/env python3
"""Bounded subprocess adapter for the fixed IntInf conformance/benchmark corpus.

Arithmetic fixtures use Python integers as an additional independent oracle:
// is floor division; truncating division explicitly uses magnitudes and sign.
Expected benchmark answers are calculated before executing any Rune code.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import resource
import shlex
import signal
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tests/intinf'
SEED = 0x52494E46


def sml(n):
    return str(n).replace('-', '~')


def quoted(s):
    return json.dumps(s)


def vectors():
    rng = random.Random(SEED)
    pairs = [(a, b) for a in range(-9, 10) for b in (-7, -1, 1, 7)]
    for bits in (15, 30, 31, 32, 62, 63, 64, 127, 255):
        for delta in (-1, 0, 1):
            for sign in (-1, 1):
                pairs.append((sign * ((1 << bits) + delta), (1 << max(1, bits // 2)) - 1))
    for _ in range(100):
        a, b = rng.getrandbits(rng.randrange(1, 257)), rng.getrandbits(rng.randrange(1, 129)) or 1
        pairs.append((a * rng.choice((-1, 1)), b * rng.choice((-1, 1))))
    rows = []
    for a, b in pairs:
        q = abs(a) // abs(b) * (-1 if (a < 0) != (b < 0) else 1)
        values = [a+b, a-b, a*b, a//b, a%b, q, a-q*b,
                  a & b, a | b, a ^ b, ~a, a << 31, a >> 31]
        rows.append('(' + ','.join((quoted(sml(a)), quoted(sml(b)),
                    '[' + ','.join(quoted(sml(v)) for v in values) + ']')) + ')')
    return 'structure IntInfVectors = struct\nval cases = [\n' + ',\n'.join(rows) + '\n]\nend\n', len(pairs)*5+4


def workload(w):
    rng = random.Random(SEED + w['bits'] * 31 + w['other_bits'])
    a = rng.getrandbits(w['bits']) | (1 << (w['bits']-1))
    b = rng.getrandbits(w['other_bits']) | (1 << (w['other_bits']-1))
    x = a + 1  # The last descending loop iteration has i = 1.
    op = w['op']
    bodies = {'add': 'I.+ (x,b)', 'mul': 'I.* (x,b)', 'div': '#1 (I.divMod (x,b))',
              'bits': 'I.xorb (I.andb (x,b), I.~>> (x,0w31))',
              'convert': 'valOf (I.fromString (I.toString x))',
              'pow': 'I.pow (x,1024)', 'factorial': 'fact (300, I.fromInt 1)'}
    expected = {'add': lambda: x+b, 'mul': lambda: x*b, 'div': lambda: x//b,
                'bits': lambda: (x & b) ^ (x >> 31), 'convert': lambda: x,
                'pow': lambda: x**1024, 'factorial': lambda: math.factorial(300)}[op]()
    source = f'''structure IntInfWorkload = struct
  structure I = IntInf
  val a = valOf (I.fromString {quoted(sml(a))})
  val b = valOf (I.fromString {quoted(sml(b))})
  val answer = ref (I.fromInt 0)
  fun fact (0, acc) = acc
    | fact (n, acc) = fact (n-1, I.* (acc,I.fromInt n))
  fun loop 0 = ()
    | loop i = let val x = I.+ (a,I.fromInt (i mod 17))
               in answer := {bodies[op]}; loop (i-1) end
  val started = Time.now ()
  val () = loop {w['iterations']}
  val elapsed = Time.- (Time.now (), started)
  val () = print ("TIMING " ^ Time.fmt 6 elapsed ^ "\\n")
  val () = print (I.toString (!answer) ^ "\\n")
end
'''
    return source, sml(expected)+'\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rune', default='bin/rune')
    parser.add_argument('--vm', default='bin/runevm')
    parser.add_argument('--target', choices=('registers', 'stack'), default='registers')
    parser.add_argument('--vm-options', default='')
    parser.add_argument('--bench', action='store_true')
    parser.add_argument('--paired-oracle', action='store_true', help='alternate current and saved-oracle runs')
    parser.add_argument('--compiler-workloads', action='store_true')
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--out', default='tests/out/intinf/current')
    args = parser.parse_args()
    if args.samples < 2:
        parser.error('at least two samples are required')
    os.chdir(ROOT)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    compiler = str(Path(args.rune).resolve())
    vm = [str(Path(args.vm).resolve()), *shlex.split(args.vm_options)]
    environment = {k:v for k,v in os.environ.items()
                   if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
    environment['LC_ALL'] = 'C'
    counter = 0

    def execute(command, label, timeout=180):
        nonlocal counter
        counter += 1
        prefix = out / f'{counter:03d}-{label}'
        command = list(map(str, command))
        prefix.with_suffix('.command.json').write_text(json.dumps(command))
        def limits():
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
            resource.setrlimit(resource.RLIMIT_AS, (4*1024**3, 4*1024**3))
        started = time.perf_counter_ns()
        p = subprocess.Popen(['/usr/bin/time', '-f', '%U %S %M', '-o', str(prefix)+'.usage', *command],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
                             preexec_fn=limits, env=environment)
        try:
            stdout, stderr = p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            os.killpg(p.pid, signal.SIGKILL)
            stdout, stderr = p.communicate()
            prefix.with_suffix('.stdout').write_bytes(stdout)
            prefix.with_suffix('.stderr').write_bytes(stderr)
            prefix.with_suffix('.status').write_text('timeout\n')
            raise RuntimeError(f'timeout: {label}') from exc
        except BaseException:
            os.killpg(p.pid, signal.SIGKILL)
            p.communicate()
            raise
        seconds = (time.perf_counter_ns()-started)/1e9
        prefix.with_suffix('.stdout').write_bytes(stdout)
        prefix.with_suffix('.stderr').write_bytes(stderr)
        prefix.with_suffix('.status').write_text(f'exit:{p.returncode}\n')
        if p.returncode:
            raise RuntimeError(f'{label}: exit {p.returncode}: {stderr.decode(errors="replace")}')
        user, system, rss = Path(str(prefix)+'.usage').read_text().strip().split()
        return stdout.decode(), {'seconds':seconds, 'user_seconds':float(user),
                                  'system_seconds':float(system), 'max_rss_kib':int(rss),
                                  'stderr':stderr.decode()}

    def compile(source, name, extra=()):
        rbc = out / (name+'.rbc')
        rbc.unlink(missing_ok=True)
        _, usage = execute([compiler, '--lib', 'lib', '--target='+args.target,
                            '-o', rbc, *extra, source], name+'-compile')
        return rbc, usage

    src, count = vectors()
    fixture = out/'vectors.sml'
    fixture.write_text(src)
    rbc, _ = compile(HERE/'checks.sml', 'checks', [HERE/'oracle.sml', fixture])
    stdout, _ = execute([*vm, rbc], 'checks')
    assert stdout == f'current: {count} checks\noracle: {count} checks\n', stdout
    print(stdout, end='', flush=True)
    if not args.bench:
        return
    report = {'schema':1, 'seed':SEED, 'target':args.target, 'vm_options':args.vm_options,
              'revision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
              'machine':platform.uname()._asdict(),
              'clock':'Time.now microseconds for kernel; perf_counter_ns for process wall time',
              'warmups':1, 'samples':args.samples, 'workloads':{}, 'compiler_workloads':{}}
    report['source_hashes'] = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in [HERE/'run.py',HERE/'checks.sml',HERE/'oracle.sml',HERE/'workloads.json',ROOT/'lib/basis/intinf.sml']}
    report['tool_hashes'] = {p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
                            for p in (compiler,vm[0],str(ROOT/'bin/rune.rbc'))}
    report['loadavg'] = list(os.getloadavg())
    report['paired_oracle'] = args.paired_oracle
    report['versions'] = {p:subprocess.check_output([p,'--version'],text=True).strip() for p in (compiler,vm[0])}
    report['cpu'] = next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                          if line.startswith('model name')), 'unknown')
    report['source_status'] = subprocess.check_output(['git','status','--porcelain'],text=True)
    report['c_compiler'] = subprocess.check_output(['cc','--version'],text=True).splitlines()[0]
    for name in report['source_hashes']:
        copy = out/'sources'/name
        copy.parent.mkdir(parents=True,exist_ok=True)
        copy.write_bytes((ROOT/name).read_bytes())
    for w in json.loads((HERE/'workloads.json').read_text()):
        source, expected = workload(w)
        path = out/(w['name']+'.sml')
        path.write_text(source)
        (out/(w['name']+'.expected')).write_text(expected)
        rbc, compile_usage = compile(path, w['name'])
        oracle = None
        if args.paired_oracle:
            oracle_path = out/(w['name']+'-oracle.sml')
            oracle_path.write_text(source.replace('structure I = IntInf\n','structure I = IntInfOracle\n'))
            oracle, _ = compile(oracle_path, w['name']+'-oracle', [HERE/'oracle.sml'])
        measurements = []
        oracle_measurements = []
        for i in range(args.samples+1):
            runs = [(rbc, measurements, 'current')]
            if oracle:
                runs.append((oracle, oracle_measurements, 'oracle'))
            for program, samples, backend in (runs if i % 2 else list(reversed(runs))):
                stdout, usage = execute([*vm,program], w['name']+f'-{backend}-{i}')
                timing, answer = stdout.split('\n',1)
                assert timing.startswith('TIMING ') and answer == expected, (w['name'],stdout,expected)
                usage['kernel_seconds'] = float(timing[7:])
                assert usage['kernel_seconds'] >= 0
                if i:
                    samples.append(usage)
        stdout, instrumented = execute([*vm,'--count','--stats',rbc], w['name']+'-instrumented')
        # The instrumented transcript is separate from all headline timing samples.
        assert stdout.split('\n',1)[1] == expected
        report['workloads'][w['name']] = {**w, 'compile':compile_usage, 'runs':measurements,
                                         'source_sha256':hashlib.sha256(source.encode()).hexdigest(),
                                         'expected':expected, 'instrumented':instrumented['stderr'],
                                         'median_seconds':statistics.median(x['kernel_seconds'] for x in measurements)}
        if oracle:
            entry = report['workloads'][w['name']]
            entry['oracle_runs'] = oracle_measurements
            entry['oracle_median_seconds'] = statistics.median(x['kernel_seconds'] for x in oracle_measurements)
            entry['paired_speedup'] = statistics.median(o['kernel_seconds']/c['kernel_seconds']
                                                       for o,c in zip(oracle_measurements,measurements))
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(w['name'], report['workloads'][w['name']]['median_seconds'], flush=True)
    if args.compiler_workloads:
        sources = [line for line in (ROOT/'sources.txt').read_text().splitlines() if line and not line.startswith('#')]
        for name, inputs in [('compile-hello',['examples/hello.sml']),
                             ('compile-sigs',['tests/perf/compile-sigs.sml']),
                             ('bootstrap',['build/config.sml',*sources,'src/main/rune-main.sml'])]:
            runs=[]
            target=out/(name+'.rbc')
            for i in range(args.samples+1):
                target.unlink(missing_ok=True)
                _, usage=execute([compiler,'--lib','lib','--target='+args.target,'-o',target,*inputs],name+f'-{i}')
                if i:
                    runs.append(usage)
            report['compiler_workloads'][name]={'inputs':inputs,'runs':runs,
                                               'median_seconds':statistics.median(x['seconds'] for x in runs),
                                               'output_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    main()
