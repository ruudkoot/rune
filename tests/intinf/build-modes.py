#!/usr/bin/env python3
"""Verify Makefile backend switches in an isolated copy of the current sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--out',default='tests/out/intinf/build-modes')
p.add_argument('--prefix',default='build/deps/gmp/native')
a = p.parse_args()
os.chdir(root)
out = (root/a.out).resolve(); out.relative_to(root/'tests/out')
stage = out/'tree'; stage.mkdir(parents=True,exist_ok=True)
prefix = (root/a.prefix).resolve()
files = subprocess.check_output(['git','ls-files','-z']).split(b'\0')
files += subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z']).split(b'\0')
for raw in files:
    if not raw: continue
    name = os.fsdecode(raw)
    source = root/name
    if source.is_file():
        target = stage/name; target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
for name in ['runtime/version.h','build/config.sml']:
    target = stage/name; target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,target)
env = {k:v for k,v in os.environ.items() if not k.startswith('RUNEVM_') and k not in ['GMP','GMP_PREFIX','MAKEFLAGS','MFLAGS']}
reports = []
for label,mode,location,enabled,success in [
        ('pinned','yes',prefix,True,True),('disabled','no','',False,True),
        ('pinned-again','yes',prefix,True,True),('automatic-missing','auto',out/'missing',False,True),
        ('required-missing','yes',out/'missing',False,False)]:
    command = ['make','bin/runevm','DOCTOR=no','JOBS=4','GMP='+mode,'GMP_PREFIX='+str(location)]
    result = subprocess.run(command,cwd=stage,env=env,capture_output=True,timeout=180)
    (out/(label+'.command.json')).write_text(json.dumps(command)+'\n')
    (out/(label+'.stdout')).write_bytes(result.stdout)
    (out/(label+'.stderr')).write_bytes(result.stderr)
    assert (result.returncode == 0) == success,(label,result.stderr.decode())
    record = {'name':label,'exit':result.returncode}
    if success:
        vm = stage/'bin/runevm'
        version = subprocess.check_output([vm,'--version'],env=env,text=True)
        assert ('GMP headers' in version) == enabled,(label,version)
        record.update(version=version,vm_sha256=hashlib.sha256(vm.read_bytes()).hexdigest())
    reports.append(record)
    print(label,'pass',flush=True)
assert reports[0]['vm_sha256'] == reports[2]['vm_sha256'],'switching back did not reproduce the pinned VM'
(out/'report.json').write_text(json.dumps(reports,indent=2)+'\n')
