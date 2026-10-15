#!/usr/bin/env python3
"""Import/copy/export and packed-storage roundtrips, timed separately."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import statistics
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--samples',type=int,default=7);p.add_argument('--out',default='tests/out/intinf/conversion')
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k!='RUNE_GC_STRESS'}
seq=0

def run(command):
    global seq
    seq+=1;command=list(map(str,command));prefix=out/f'{seq:03d}'
    def limit():
        resource.setrlimit(resource.RLIMIT_CORE,(0,0));resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
    child=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True,preexec_fn=limit)
    try:stdout,stderr=child.communicate(timeout=180)
    except BaseException:
        try:os.killpg(child.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        stdout,stderr=child.communicate();prefix.with_suffix('.status').write_text('timeout/interrupted\n');raise
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
    prefix.with_suffix('.status').write_text(str(child.returncode)+'\n')
    assert child.returncode==0,stderr.decode()
    return stdout.decode(),stderr.decode()

rng=random.Random(0x434f4e56)
report={'seed':0x434f4e56,'samples':a.samples,'warmup_pairs':1,'iterations':50000,
        'description':'GMP pow(1) includes import, copy, export and result allocation; storage roundtrip includes scratch allocation. Neither is isolated import latency.',
        'affinity':sorted(os.sched_getaffinity(0)),'load_start':os.getloadavg(),'results':{}}
report['vm_sha256']=hashlib.sha256(Path('bin/runevm').read_bytes()).hexdigest()
report['compiler_sha256']=hashlib.sha256(Path('bin/rune.rbc').read_bytes()).hexdigest()
report['source_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path('runtime/intinf.c'),Path('lib/basis/intinf.sml')]}
for bits in [8,32,64,128,256,1024,4096,16384]:
    value=rng.getrandbits(bits)|(1<<(bits-1));data=value.to_bytes((bits+7)//8,'little')
    literal='"'+''.join('\\'+str(b).zfill(3) for b in data)+'"'
    programs={}
    for mode,expression in [('gmp','#2(native(false,packed,1))'),('storage','encode(decode(packed,30),'+str((len(data)*8+29)//30)+',30)')]:
        source=f'''val native = _prim "intinf_power" : bool * string * int -> bool * string
val decode = _prim "intinf_unpack" : string * int -> int array
val encode = _prim "intinf_pack" : int array * int * int -> string
val packed = {literal}
val answer = ref ""
fun loop 0 = () | loop n = (answer := {expression}; loop(n-1))
val start = Time.now()
val () = loop 50000
val elapsed = Time.-(Time.now(),start)
val () = if !answer=packed then print("TIMING " ^ Time.fmt 6 elapsed ^ "\\n") else raise Fail "roundtrip"
'''
        path=out/f'{bits}-{mode}.sml';path.write_text(source);rbc=path.with_suffix('.rbc')
        run(['bin/rune','--allow-prim','-o',rbc,path]);programs[mode]=rbc
    results={'gmp':[],'storage':[]}
    for i in range(a.samples+1):
        for mode in (['gmp','storage'] if i%2 else ['storage','gmp']):
            stdout,_=run(['bin/runevm','--intinf=gmp',programs[mode]])
            assert stdout.startswith('TIMING ')
            if i:results[mode].append(float(stdout.split()[1]))
    entry={'runs':results,'median_seconds':{mode:statistics.median(v) for mode,v in results.items()},'input_sha256':hashlib.sha256(data).hexdigest(),'stats':{}}
    for mode in results:
        _,stderr=run(['bin/runevm','--intinf=gmp','--count','--stats','--intinf-stats',programs[mode]])
        entry['stats'][mode]=stderr
    report['results'][str(bits)]=entry
    print(bits,entry['median_seconds'],flush=True)
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
