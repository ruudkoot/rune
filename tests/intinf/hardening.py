#!/usr/bin/env python3
"""Bounded malformed-primitive and fork-policy checks for IntInf."""
import argparse
import json
import os
from pathlib import Path
import resource
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--vm',default='bin/runevm')
p.add_argument('--out',default='tests/out/intinf/hardening')
p.add_argument('--fork-only',action='store_true')
p.add_argument('--native',action='store_true',help='also exercise native output and its runtime options')
p.add_argument('--alloc-test',default='build/intinf-alloc-test')
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
seq=0

def run(command,overrides=None):
    global seq
    seq+=1;command=list(map(str,command));prefix=out/f'{seq:03d}'
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    if overrides:prefix.with_suffix('.environment.json').write_text(json.dumps(overrides)+'\n')
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        if 'asan' not in command[0]:resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    child=subprocess.Popen(command,env={**env,**(overrides or {})},stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,preexec_fn=limits)
    try: stdout,stderr=child.communicate(timeout=60)
    except BaseException:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        stdout,stderr=child.communicate()
        prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
        prefix.with_suffix('.status').write_text('timeout/interruption\n');raise
    prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(child.returncode)+'\n')
    return child.returncode,stdout,stderr

def compile(name,source,target='registers'):
    path=out/(name+'.sml');path.write_text(source);rbc=path.with_suffix('.rbc')
    code,_,err=run(['bin/rune','--allow-prim','--target='+target,'-o',rbc,path]);assert code==0,err.decode()
    return rbc

fork=compile('fork', '''val available = _prim "intinf_gmp_available" : unit -> bool
val previous = available()
val () = case Posix.Process.fork() of
  NONE => (if available() = previous then print "child policy preserved\\n"
           else print "child policy changed\\n"; TextIO.flushOut TextIO.stdOut;
           Posix.Process.exit (if available() = previous then 0w0 else 0w3))
| SOME pid => (case Posix.Process.waitpid(Posix.Process.W_CHILD pid,[]) of
    (_,Posix.Process.W_EXITED) => print "parent pass\\n"
  | _ => raise Fail "child backend policy")
''')
failures=[]
code,version,stderr=run([a.vm,'--version']);assert code==0,stderr
has_gmp=b'GMP headers ' in version and b', supported\n' in version
modes=['sml','gmp'] if has_gmp else ['sml']
for mode in modes:
    for emulated in [False,True]:
        for inherited in [None,'gmp' if mode=='sml' else 'sml','invalid']:
            code,stdout,stderr=run([a.vm,'--intinf='+mode,*(['--emulate-fork'] if emulated else []),fork],
                                  {'RUNEVM_INTINF':inherited} if inherited else None)
            if code!=0 or stdout!=b'child policy preserved\nparent pass\n':failures.append((mode,emulated,inherited,code,stdout.decode(),stderr.decode()))
if a.fork_only:
    assert not failures,failures
    print('fork policies pass');raise SystemExit(0)

if a.native:
    stack=compile('fork-stack',(out/'fork.sml').read_text(),'stack')
    native=out/'fork-native'
    code,_,stderr=run(['bin/runeopt',stack,'-o',native]);assert code==0,stderr.decode()
    for emulated in [False,True]:
        for inherited in ['gmp','invalid']:
            code,stdout,stderr=run([native],{'RUNEVM_INTINF':inherited,
                'RUNEVM_OPTIONS':'--intinf=sml'+(' --emulate-fork' if emulated else '')})
            if code!=0 or stdout!=b'child policy preserved\nparent pass\n':failures.append(('native',emulated,inherited,code,stderr.decode()))

binary='int * bool * string * bool * string -> bool * string'
divmod='bool * bool * string * bool * string -> (bool * string) * (bool * string)'
cases=[
 ('operation',f'val f = _prim "intinf_binary" : {binary}\nval _ = f(6,false,"",false,"")','invalid operation'),
 ('boolean','val f = _prim "intinf_binary" : int * int * string * bool * string -> bool * string\nval _ = f(0,2,"",false,"")','invalid boolean'),
 ('unit','val f = _prim "intinf_max_bits" : int -> int\nval () = print(Int.toString(f 1))','expected unit'),
 ('bitcount','val f = _prim "intinf_check_bits" : int -> unit\nval _ = f (~1)','negative bit count'),
 ('string','val f = _prim "intinf_binary" : int * bool * int ref * bool * string -> bool * string\nval _ = f(0,false,ref 1,false,"")','wrong magnitude type'),
 ('leading-zero',f'val f = _prim "intinf_binary" : {binary}\nval _ = f(0,false,"\\001\\000",false,"")','noncanonical magnitude'),
 ('negative-zero',f'val f = _prim "intinf_binary" : {binary}\nval _ = f(0,true,"",false,"")','negative zero'),
 ('div-negative-zero',f'val f = _prim "intinf_divmod" : {divmod}\nval _ = f(true,false,"\\001",true,"")','negative zero'),
 ('div-leading-zero',f'val f = _prim "intinf_divmod" : {divmod}\nval _ = f(true,false,"\\001\\000",false,"")','noncanonical magnitude'),
 ('exponent','val f = _prim "intinf_power" : bool * string * int -> bool * string\nval _ = f(false,"\\001",~1)','negative exponent'),
]
for name,source,message in cases:
    if not has_gmp and name not in ['operation','boolean','unit','bitcount','div-negative-zero','div-leading-zero','exponent']:
        continue
    program=compile(name,source)
    code,stdout,stderr=run([a.vm,'--intinf='+('gmp' if has_gmp else 'sml'),'--gc-stress','1',program])
    if code!=2 or message.encode() not in stderr:failures.append((name,code,stdout.decode(),stderr.decode()))
zero=compile('div-zero',f'val f = _prim "intinf_divmod" : {divmod}\nval () = (f(true,false,"\\001",false,""); raise Fail "missing Div") handle Div => print "Div before GMP\\n"\n')
code,stdout,stderr=run([a.vm,'--intinf='+('gmp' if has_gmp else 'sml'),'--intinf-gmp-memory','1',zero])
if code!=0 or stdout!=b'Div before GMP\n':failures.append(('zero divisor',code,stdout.decode(),stderr.decode()))

# Reject malformed policy/limits before reading the heap. A larger saved
# memory cap is valid and is narrowed to the current invocation's cap.
image=out/'policy.img'
writer=compile('policy',f'val () = case Runtime.save {json.dumps(str(image))} of Runtime.Saved => print "saved\\n" | Runtime.Restored => print "restored\\n"\n')
code,stdout,stderr=run([a.vm,writer]);assert code==0 and stdout==b'saved\n',stderr
data=image.read_bytes();start=data.index(b'\0')+1
for name,offset,width,value,message in [
    ('mode',28,4,3,'bad IntInf policy'),('stats',32,4,2,'bad IntInf policy'),
    ('bits-zero',52,8,0,'bad IntInf limits'),('bits-large',52,8,1073741823,'bad IntInf limits'),
    ('memory-zero',60,8,0,'bad IntInf limits')]:
    patched=bytearray(data);patched[start+offset:start+offset+width]=value.to_bytes(width,'little')
    path=out/(name+'.img');path.write_bytes(patched)
    code,_,stderr=run([a.vm,'--restore',path])
    if code!=2 or message.encode() not in stderr:failures.append((name,code,stderr.decode()))
patched=bytearray(data);patched[start+60:start+68]=(2**64-1).to_bytes(8,'little')
path=out/'memory-wide.img';path.write_bytes(patched)
code,stdout,stderr=run([a.vm,'--intinf-gmp-memory','128','--intinf-stats','--restore',path])
if code!=0 or stdout!=b'restored\n' or b'GMP memory limit 128,' not in stderr:failures.append(('wide saved cap',code,stderr.decode()))

allocation_checks=[]
if Path(a.alloc_test).exists():
    for mode in ['success','malloc','realloc']:
        code,stdout,stderr=run([a.alloc_test,mode])
        if code==77:
            allocation_checks.append('unavailable');break
        if code!=(0 if mode=='success' else 2) or (mode!='success' and b'intinf GMP allocation failed' not in stderr):
            failures.append(('allocation',mode,code,stderr.decode()))
        allocation_checks.append(mode)
assert not failures,failures
(out/'report.json').write_text(json.dumps({'subprocesses':seq,'result':'pass','native':a.native,'has_gmp':has_gmp,
                                        'allocation_checks':allocation_checks},indent=2)+'\n')
print(f'IntInf hardening: {seq} bounded subprocesses pass')
