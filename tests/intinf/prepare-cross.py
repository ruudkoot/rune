#!/usr/bin/env python3
"""Preserve GMP-free platform binaries, then rebuild the enabled counterparts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser()
p.add_argument('--out',default='tests/out/intinf/cross-builds')
p.add_argument('--prefix',default='build/deps/gmp/native')
p.add_argument('--jobs',type=int,default=4)
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
assert a.jobs>0
commands=[['make','-j',str(a.jobs),'windows','portability','bin/runevm-sml','GMP=no'],
          ['make','-j',str(a.jobs),'windows','portability','vm','boot','GMP=yes','GMP_PREFIX='+a.prefix]]
(out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
with (out/'disabled.log').open('w') as log:subprocess.run(commands[0],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
free=out/'sml-vms';free.mkdir(exist_ok=True)
names=['runevm-sml','runevm32','runevm-ppc64','runevm-ppc64.bin','runevm-aarch64','runevm-aarch64.bin','runevm.exe','runevm32.exe']
for name in names:shutil.copy2(ROOT/'bin'/name,free/name)
(free/'hashes.json').write_text(json.dumps({name:hashlib.sha256((free/name).read_bytes()).hexdigest() for name in names},indent=2)+'\n')
for platform in ['linux32','ppc64','aarch64','windows64','windows32']:
    target=free/'configs'/platform;target.mkdir(parents=True,exist_ok=True)
    for name in ['config.json','config.h','linked.json']:shutil.copyfile(ROOT/'build/gmp'/platform/name,target/name)
with (out/'enabled.log').open('w') as log:subprocess.run(commands[1],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
print('preserved GMP-free binaries in',free)
