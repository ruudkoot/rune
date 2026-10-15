#!/usr/bin/env python3
"""One register bytecode, both arithmetic backends, finite limits and images."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shlex
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--vm', default='bin/runevm')
p.add_argument('--sml-vm', default='bin/runevm-sml')
p.add_argument('--rune', default='bin/rune')
p.add_argument('--out', default='tests/out/intinf/backends')
p.add_argument('--stress', action='store_true')
p.add_argument('--vm-options', default='', help='collector options applied to both VM builds')
a = p.parse_args()
os.chdir(ROOT)
out = Path(a.out).resolve(); out.mkdir(parents=True,exist_ok=True)
env = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
env['LC_ALL'] = 'C'
sequence = 0

def run(command):
    global sequence
    sequence += 1
    command = list(map(str,command))
    if command[0] in [a.vm, a.sml_vm]:
        command[1:1] = shlex.split(a.vm_options)
    prefix = out/f'{sequence:03d}'
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        # ASan reserves a large virtual shadow mapping; the timeout remains.
        if 'asan' not in command[0]:
            resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    process = subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                               start_new_session=True,preexec_fn=limits)
    try:
        stdout,stderr = process.communicate(timeout=180)
    except BaseException as error:
        try:
            os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:
            pass
        stdout,stderr = process.communicate()
        prefix.with_suffix('.stdout').write_bytes(stdout)
        prefix.with_suffix('.stderr').write_bytes(stderr)
        prefix.with_suffix('.status').write_text('timeout after 180 seconds\n' if isinstance(error,subprocess.TimeoutExpired) else 'interrupted\n')
        raise
    prefix.with_suffix('.stdout').write_bytes(stdout)
    prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(process.returncode)+'\n')
    return process.returncode,stdout,stderr


def compile(name,source):
    sml = out/(name+'.sml'); sml.write_text(source)
    rbc = out/(name+'.rbc')
    status,_,err = run([a.rune,'--target=registers','-o',rbc,sml])
    assert status == 0,err.decode()
    return rbc


def invoke(vm,mode,program,*flags,stress_every=1):
    opts = ['--gc-stress',str(stress_every)] if a.stress else []
    return run([vm,'--intinf='+mode,'--intinf-stats',*opts,*flags,program])

status,version,err = run([a.vm,'--version'])
assert status == 0,err
has_gmp = b'GMP headers ' in version and b', supported\n' in version
backends = ([('gmp',a.vm)] if has_gmp else []) + [('sml',a.vm),('auto',a.sml_vm)]
# Reuse the independent arithmetic fixtures and bounded list oracle, compiled once.
status,_,err = run(['python3','tests/intinf/run.py','--rune',a.rune,'--vm',a.sml_vm,
                  '--vm-options=--intinf=sml','--out',out/'semantic'])
assert status == 0,err.decode()
bytecode = out/'semantic/checks.rbc'
expected = b'current: 1154 checks\noracle: 1154 checks\n'
counts = {}
for backend,vm in backends:
    for tier in ['off','1','2']:
        flags = ['--jit=off'] if tier == 'off' else ['--jit=all','--jit-tier='+tier]
        # The preserved list oracle allocates heavily. Compact cases below
        # stress every allocation; the full corpus uses an interval of 101.
        status,stdout,stderr = invoke(vm,backend,bytecode,'--count',*flags,stress_every=101)
        assert status == 0 and stdout == expected,(backend,tier,stderr.decode())
        count = re.search(rb'runevm: count: ([^\n]+)',stderr).group(1)
        arithmetic = re.search(rb'(\d+) GMP calls,.* (\d+) GMP live',stderr)
        assert arithmetic and arithmetic.group(2) == b'0',stderr
        assert (int(arithmetic.group(1)) > 0) == (backend == 'gmp'),stderr
        counts[backend,tier] = count
    assert len({counts[backend,t] for t in ['off','1','2']}) == 1,counts
assert counts['sml','off'] == counts['auto','off'],counts

pairs = compile('rooted-pairs', '''structure I = IntInf
val one = I.fromInt 1
val two = I.fromInt 2
val p = I.pow(two,200)
val a = I.+(I.*(p,p),one)
val b = I.+(p,one)
val q = I.-(p,one)
val checks = [I.divMod(a,b)=(q,two), I.quotRem(I.~ a,b)=(I.~ q,I.~ two),
 I.divMod(I.~ a,b)=(I.~ p,q), I.divMod(a,I.~ b)=(I.~ p,I.~ q),
 I.divMod(I.~ a,I.~ b)=(q,I.~ two), I.+(I.*(q,b),two)=a]
val () = if List.all (fn x => x) checks then print "rooted pairs pass\\n" else raise Fail "rooted pairs"
''')
for backend,vm in backends:
    for tier in ['off','1','2']:
        flags = ['--jit=off'] if tier == 'off' else ['--jit=all','--jit-tier='+tier]
        status,stdout,stderr = invoke(vm,backend,pairs,*flags)
        assert status == 0 and stdout == b'rooted pairs pass\n',stderr.decode()

special = compile('special', '''structure I = IntInf
val huge = Word.notb 0w0
val top = valOf Int.maxInt
val low = valOf Int.minInt
val zero = I.fromInt 0
val one = I.fromInt 1
val minus = I.fromInt (~1)
val checks = [I.<<(zero,huge)=zero, I.~>>(one,huge)=zero,
 I.~>>(minus,huge)=minus, I.pow(zero,top)=zero,
 I.pow(one,top)=one, I.pow(minus,top)=minus,
 I.pow(minus,low)=one, I.pow(I.fromInt 2,low)=zero,
 (I.pow(zero,low); false) handle Div => true]
val () = if List.all (fn b => b) checks then print "special cases pass\\n" else raise Fail "special cases"
''')
failures = {
    'shift':'I.<<(I.fromInt 1,Word.notb 0w0)',
    'power':'I.pow(I.fromInt 2,1000000000)',
    'multiply':'I.*(I.pow(I.fromInt 2,100),I.pow(I.fromInt 2,100))',
    'carry':'I.+(valOf(I.fromString "340282366920938463463374607431768211455"),I.fromInt 1)',
    'parse':'valOf(I.fromString "340282366920938463463374607431768211456")',
}
programs = {name:compile(name,'structure I = IntInf\nval answer = '+expr+'\nval () = print "unexpected result\\n"\n')
            for name,expr in failures.items()}
for backend,vm in backends:
    # Word64's Basis initialization constructs 2^64 (65 magnitude bits).
    status,stdout,stderr = invoke(vm,backend,special,'--intinf-max-bits','128')
    assert status == 0 and stdout == b'special cases pass\n',stderr.decode()
    for name,program in programs.items():
        status,stdout,stderr = invoke(vm,backend,program,'--intinf-max-bits','128')
        assert status == 2 and b'intinf magnitude limit exceeded' in stderr,(backend,name,status,stderr.decode())
        assert b'uncaught exception Overflow' not in stderr and not stdout,(name,stdout,stderr)
if has_gmp:
    status,_,stderr = invoke(a.vm,'gmp',programs['multiply'],'--intinf-gmp-memory','1')
    assert status == 2 and b'intinf GMP memory limit exceeded' in stderr,stderr
status,_,stderr = invoke(a.sml_vm,'gmp',special)
assert status == 2 and b'GMP backend is unavailable' in stderr,stderr

# A non-byte-aligned limit exercises the packed fast paths' exact final
# bit check. 65 bits also permits Word64's Basis initialization above.
budget_paths = compile('budget-paths', '''structure I = IntInf
val one = I.fromInt 1
val a = valOf(I.fromString "18446744073709551615")
val b = I.+(a,one)
val top = valOf(I.fromString "36893488147419103231")
val checks = [I.+(a,b)=top, I.*(a,I.fromInt 2)=I.-(top,one),
 I.andb(top,b)=b, I.orb(b,one)=I.+(b,one), I.xorb(b,one)=I.+(b,one),
 I.~>>(I.~ b,0w64)=I.fromInt (~1),
 I.~>>(I.~(I.+(b,one)),0w64)=I.fromInt (~2)]
val () = if List.all (fn x => x) checks then print "65-bit paths pass\\n" else raise Fail "65-bit paths"
''')
budget_failures = {
    'small-product':'I.*(I.fromInt(valOf Int.maxInt),I.fromInt(valOf Int.maxInt))',
    'packed-carry':'I.+(valOf(I.fromString "36893488147419103231"),I.fromInt 1)',
    'single-digit-product':'I.*(valOf(I.fromString "18446744073709551615"),I.fromInt 3)',
}
budget_programs = {name:compile(name,'structure I = IntInf\nval answer = '+expr+'\nval () = print "unexpected result\\n"\n')
                   for name,expr in budget_failures.items()}
for backend,vm in backends:
    status,stdout,stderr = invoke(vm,backend,budget_paths,'--intinf-max-bits','65')
    assert status == 0 and stdout == b'65-bit paths pass\n',(backend,status,stderr.decode())
    for name,program in budget_programs.items():
        status,stdout,stderr = invoke(vm,backend,program,'--intinf-max-bits','65')
        assert status == 2 and b'intinf magnitude limit exceeded' in stderr,(backend,name,status,stderr.decode())
        # A stack frame named mulOverflow is not an uncaught SML exception.
        assert b'uncaught exception Overflow' not in stderr and not stdout,(name,stdout,stderr)

image = out/'world.img'
world = compile('world', f'''structure I = IntInf
val x = I.pow(I.fromInt 2,200)
val () = case Runtime.save {json.dumps(str(image))} of
 Runtime.Saved => print "saved\\n"
 | Runtime.Restored => if I.*(x,x) = I.pow(I.fromInt 2,400)
     then print "restored\\n" else raise Fail "image arithmetic"
''')
for writer_mode,writer in ([('gmp',a.vm)] if has_gmp else []) + [('sml',a.sml_vm)]:
    for limit in [1024,256]:
        status,stdout,stderr = invoke(writer,writer_mode,world,'--intinf-max-bits',str(limit))
        assert status == 0 and stdout == b'saved\n',stderr.decode()
        for mode,reader in backends:
            status,stdout,stderr = invoke(reader,mode,image,'--intinf-max-bits','1024','--restore')
            if limit == 1024:
                assert status == 0 and stdout == b'restored\n',stderr.decode()
                calls = int(re.search(rb'(\d+) GMP calls',stderr).group(1))
                assert (calls > 0) == (mode == 'gmp'),stderr
            else:
                assert status == 2 and b'intinf magnitude limit exceeded' in stderr,stderr
            status,_,stderr = invoke(reader,mode,image,'--intinf-max-bits','64','--restore')
            assert status == 2 and b'intinf magnitude limit exceeded' in stderr,stderr

# Formatting alone must observe a stricter restored magnitude limit, and
# select the restoring VM's backend rather than the image producer's.
formatted_world = compile('format-world', f'''structure I = IntInf
val x = I.pow(I.fromInt 2,200)
val text = I.toString x
val () = case Runtime.save {json.dumps(str(image))} of
 Runtime.Saved => print "saved\\n"
 | Runtime.Restored => if I.toString x=text then print "formatted\\n" else raise Fail "image formatting"
''')
for writer_mode,writer in ([('gmp',a.vm)] if has_gmp else []) + [('sml',a.sml_vm)]:
    status,stdout,stderr = invoke(writer,writer_mode,formatted_world,'--intinf-max-bits','1024')
    assert status == 0 and stdout == b'saved\n',stderr
    for mode,reader in backends:
        for limit in [512,128]:
            status,stdout,stderr = invoke(reader,mode,image,'--intinf-max-bits',str(limit),'--restore')
            if limit == 512:
                assert status == 0 and stdout == b'formatted\n',stderr
                calls = int(re.search(rb'(\d+) GMP calls',stderr).group(1))
                assert (calls > 0) == (mode == 'gmp'),stderr
            else:
                assert status == 2 and not stdout and b'intinf magnitude limit exceeded' in stderr,stderr
(out/'report.json').write_text(json.dumps({'checks':'pass','subprocesses':sequence,
    'bytecode_sha256':hashlib.sha256(bytecode.read_bytes()).hexdigest(),
    'counts':{mode:counts[mode,'off'].decode() for mode,_ in backends},
    'has_gmp':has_gmp,
    'stress':a.stress, 'vm_options':a.vm_options},indent=2)+'\n')
print(f'IntInf backends: {sequence} bounded subprocesses pass')
