#!/usr/bin/env python3
"""Bounded probes of build modes and rejected dependency metadata."""
import json
import os
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[2]
os.chdir(root)
out = root/'tests/out/intinf/build-config'; out.mkdir(parents=True,exist_ok=True)
prefix = root/'build/deps/gmp/native'
count = 0

def check(name,mode,location,enabled,success=True):
    global count
    command = ['python3','scripts/configure-gmp.py','--mode',mode,'--prefix',str(location),'--out',str(out/name)]
    p = subprocess.run(command,capture_output=True,timeout=90)
    (out/(name+'.command.json')).write_text(json.dumps(command)+'\n')
    (out/(name+'.stdout')).write_bytes(p.stdout)
    (out/(name+'.stderr')).write_bytes(p.stderr)
    assert (p.returncode == 0) == success,(name,p.stderr)
    if success:
        record = json.loads((out/name/'config.json').read_text())
        if enabled is not None:
            assert record['enabled'] == enabled,(name,record)
    count += 1

check('disabled','no',out/'missing',False)
check('auto-missing','auto',out/'missing',False)
check('required-missing','yes',out/'missing',False,False)
check('system','auto','',None)
if (prefix/'rune-gmp.json').exists():
    check('pinned','yes',prefix,True)
    fake = out/'old-headers'
    (fake/'include').mkdir(parents=True,exist_ok=True)
    (fake/'lib').mkdir(exist_ok=True)
    header = (prefix/'include/gmp.h').read_text()
    header,n = re.subn(r'(#define __GNU_MP_VERSION_MINOR\s+)3\b',r'\g<1>2',header)
    assert n == 1
    (fake/'include/gmp.h').write_text(header)
    (fake/'lib/libgmp.a').unlink(missing_ok=True)
    (fake/'lib/libgmp.a').symlink_to(prefix/'lib/libgmp.a')
    check('auto-old','auto',fake,False)
    check('required-old','yes',fake,False,False)
    (fake/'rune-gmp.json').write_bytes((prefix/'rune-gmp.json').read_bytes())
    check('altered-pinned','yes',fake,False,False)
print(f'GMP build configuration: {count} checks pass')
