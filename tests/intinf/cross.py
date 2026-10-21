#!/usr/bin/env python3
"""Run identical arithmetic bytecode and images across native and cross VMs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--out', default='tests/out/intinf/cross')
p.add_argument('--sml-vms', required=True, help='preserved GMP-free cross VMs with their wrappers')
p.add_argument('--platform', action='append', help='restrict exploratory runs; acceptance uses all')
a = p.parse_args()
os.chdir(ROOT)
out = Path(a.out).resolve(); out.mkdir(parents=True, exist_ok=True)
free = Path(a.sml_vms).resolve()
env = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k != 'RUNE_GC_STRESS'}
env['LC_ALL'] = 'C'
sequence = 0
report = {'platforms': {}, 'images': [], 'commands': 0, 'result': 'running'}


def run(command, cwd=ROOT):
    global sequence
    sequence += 1
    command = list(map(str, command))
    prefix = out/f'{sequence:04d}'
    prefix.with_suffix('.command.json').write_text(json.dumps({'argv':command, 'cwd':str(cwd)})+'\n')
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE, (0,0))
    child = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, start_new_session=True, preexec_fn=limits)
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
    prefix.with_suffix('.stdout').write_bytes(stdout)
    prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(child.returncode)+'\n')
    return child.returncode, stdout, stderr


def save_report():
    report['commands'] = sequence
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')


def compile_program(name, source):
    path = out/(name+'.sml'); path.write_text(source)
    rbc = path.with_suffix('.rbc')
    code, _, err = run([ROOT/'bin/rune', '--allow-prim', '-o', rbc, path])
    assert code == 0, err.decode()
    return rbc


code, _, err = run(['bin/rune-intinf', 'run', '--vm', 'bin/runevm-sml',
                    '--vm-options=--intinf=sml', '--out', out/'semantic'])
assert code == 0, err.decode()
semantic = out/'semantic/checks.rbc'
expected = b'current: 1154 checks\noracle: 1154 checks\n'
image_program = compile_program('image', '''structure I = IntInf
val available = _prim "intinf_gmp_available" : unit -> bool
val limit = _prim "intinf_max_bits" : unit -> int
val x = I.+(I.pow(I.fromInt 2,500),I.fromInt 17)
val values = [x,I.~ x,I.fromInt 0]
val texts = List.map I.toString values
val () = case Runtime.save "saved.img" of
  Runtime.Saved => print "saved\\n"
| Runtime.Restored =>
    let val (q,r) = I.divMod(x,I.fromInt (~7))
    in if values=[x,I.~ x,I.fromInt 0] andalso List.map I.toString values=texts andalso
          I.+(I.*(q,I.fromInt (~7)),r)=x andalso
          I.<=(I.fromInt (~6),r) andalso I.<=(r,I.fromInt 0)
       then print("restored " ^ Bool.toString(available()) ^ " " ^ Int.toString(limit()) ^ "\\n")
       else raise Fail "cross-image arithmetic"
    end
''')
failure_program = compile_program('limit', 'val () = print(IntInf.toString(IntInf.pow(IntInf.fromInt 2,4096)))\n')
fork_program = compile_program('fork', '''structure I = IntInf
val available = _prim "intinf_gmp_available" : unit -> bool
val previous = available()
val x = I.+(I.pow(I.fromInt 2,200),I.fromInt 1)
val () = case Posix.Process.fork() of
  NONE => (if available()=previous andalso I.div(I.*(x,x),x)=x
           then print "child pass\\n" else raise Fail "fork arithmetic";
           TextIO.flushOut TextIO.stdOut; Posix.Process.exit 0w0)
| SOME pid => (case Posix.Process.waitpid(Posix.Process.W_CHILD pid,[]) of
    (_,Posix.Process.W_EXITED) => print "parent pass\\n"
  | _ => raise Fail "child failed")
''')
# Only the actual supported JIT targets get tier checks. The 32-bit and
# PowerPC VMs interpret even when given a JIT option.
platforms = [('native','runevm','runevm-sml',True),
             ('linux32','runevm32','runevm32',False),
             ('ppc64','runevm-ppc64','runevm-ppc64',False),
             ('aarch64','runevm-aarch64','runevm-aarch64',True),
             ('windows64','runevm.exe','runevm.exe',True),
             ('windows32','runevm32.exe','runevm32.exe',False)]
if a.platform:
    assert set(a.platform) <= {p[0] for p in platforms}
    platforms = [p for p in platforms if p[0] in a.platform]
windir = None
if any(name.startswith('windows') for name,_,_,_ in platforms):
    code, stdout, err = run(['sh','tests/windows-dir.sh'])
    assert code == 0, err.decode()
    windir = Path(stdout.decode().strip())/'intinf-cross'
consumers = []
images = []
counts = {}
for name, binary, free_binary, jit in platforms:
    vm, free_vm = ROOT/'bin'/binary, free/free_binary
    directory = (windir/name if name.startswith('windows') else out/name)
    directory.mkdir(parents=True, exist_ok=True)
    for source, target in [(semantic,'checks.rbc'),(image_program,'image.rbc'),
                           (failure_program,'limit.rbc'),(fork_program,'fork.rbc')]:
        shutil.copyfile(source, directory/target)
    versions = {}
    for label, executable in [('enabled',vm),('disabled',free_vm)]:
        code, stdout, stderr = run([executable,'--version'],directory)
        assert code == 0, (name,label,stderr.decode())
        assert (b'GMP headers ' in stdout) == (label=='enabled'), (name,label,stdout)
        versions[label] = stdout.decode()
    report['platforms'][name] = {'versions':versions,'jit':jit,'counts':{},'native_stats':{},
        'vm_sha256':hashlib.sha256(vm.read_bytes()).hexdigest(),
        'free_vm_sha256':hashlib.sha256(free_vm.read_bytes()).hexdigest()}
    tiers = [('off',['--jit=off'])] + ([('1',['--jit=all','--jit-tier=1']),('2',['--jit=all','--jit-tier=2'])] if jit else [])
    for label, executable, mode in [('gmp',vm,'gmp'),('sml',vm,'sml'),('free',free_vm,'auto')]:
        common = [executable,'--intinf='+mode,'--heap-limit','536870912','--intinf-stats']
        local_counts = []
        for tier, flags in tiers:
            code, stdout, stderr = run([*common,'--intinf-max-bits','1048576','--count',*flags,'checks.rbc'],directory)
            assert code == 0 and stdout == expected,(name,label,tier,stderr.decode())
            count = re.search(rb'runevm: count: ([^\n]+)',stderr).group(1).decode()
            native = re.search(rb'(\d+) GMP calls,.* (\d+) GMP live',stderr)
            assert native and native.group(2)==b'0' and ((int(native.group(1))>0)==(label=='gmp'))
            local_counts.append(count)
            report['platforms'][name]['counts'][label+'/'+tier] = count
            report['platforms'][name]['native_stats'][label+'/'+tier] = stderr.decode()
        assert len(set(local_counts))==1,(name,label,local_counts)
        counts.setdefault('gmp' if label=='gmp' else 'sml',set()).add(local_counts[0])
        code,_,stderr = run([*common,'--intinf-max-bits','1024','limit.rbc'],directory)
        assert code == 2 and b'intinf magnitude limit exceeded' in stderr,(name,label,stderr.decode())
        for emulated in [False,True]:
            code,stdout,stderr = run([*common,*(['--emulate-fork'] if emulated else []),'fork.rbc'],directory)
            assert code == 0 and stdout==b'child pass\nparent pass\n',(name,label,emulated,stderr.decode())
        if label != 'sml':
            code,stdout,stderr = run([*common,'--intinf-max-bits','2048','--intinf-gmp-memory','8192','image.rbc'],directory)
            assert code == 0 and stdout==b'saved\n',(name,label,stderr.decode())
            saved = out/(name+'-'+label+'.img'); shutil.copyfile(directory/'saved.img',saved)
            images.append((name+'/'+label,saved))
        consumers.append((name+'/'+label,directory,common,label=='gmp'))
    code,_,stderr = run([free_vm,'--intinf=gmp','checks.rbc'],directory)
    assert code == 2 and b'requested GMP backend is unavailable' in stderr,(name,stderr.decode())
    print(name,'arithmetic, limits, forks and image production pass',flush=True)
    save_report()
assert all(len(c)==1 for c in counts.values()),counts
for producer,source in images:
    for consumer,directory,common,gmp in consumers:
        shutil.copyfile(source,directory/'restore.img')
        for bits,memory in [(1024,4096),(4096,16384)]:
            code,stdout,stderr = run([*common,'--intinf-max-bits',str(bits),
                                     '--intinf-gmp-memory',str(memory),'--restore','restore.img'],directory)
            expected_restore = f'restored {str(gmp).lower()} {min(bits,2048)}\n'.encode()
            assert code == 0 and stdout==expected_restore,(producer,consumer,bits,stderr.decode())
            assert f'GMP memory limit {min(memory,8192)},'.encode() in stderr
        report['images'].append({'producer':producer,'consumer':consumer,'limits':'stricter saved and invocation pass'})
    print(producer,'restores on every consumer',flush=True)
    save_report()
report['result'] = 'pass'
report['semantic_bytecode_sha256'] = hashlib.sha256(semantic.read_bytes()).hexdigest()
save_report()
print(f'IntInf cross-platform: {sequence} bounded subprocesses pass',flush=True)
