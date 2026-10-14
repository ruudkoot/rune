#!/usr/bin/env python3
"""Check pinned dependency artifacts and the retained division regression."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--platform', action='append')
p.add_argument('--require-all', action='store_true')
p.add_argument('--out', default='tests/out/intinf/dependency')
a = p.parse_args(); os.chdir(ROOT)
out = Path(a.out).resolve(); out.mkdir(parents=True,exist_ok=True)
platforms = a.platform or (['native','linux32','ppc64','aarch64','windows64','windows32'] if a.require_all else ['native'])
results = {}
for platform in platforms:
    prefix = ROOT/'build/deps/gmp'/platform
    metadata = prefix/'rune-gmp.json'
    if not metadata.exists():
        if a.require_all: raise SystemExit(f'missing pinned dependency: {platform}')
        results[platform] = {'result':'not installed'}
        continue
    record = json.loads(metadata.read_text())
    for name,path in [('header',prefix/'include/gmp.h'),('library',prefix/'lib/libgmp.a')]:
        assert hashlib.sha256(path.read_bytes()).hexdigest()==record[name+'_sha256'],(platform,name)
    config = record['config']
    assert config['version']=='6.3.0' and config['sha256']=='a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898'
    binary = out/(platform+'.exe')
    commands = [[*shlex.split(config['cc']),*shlex.split(config['cflags']),
                 '-I'+str(prefix/'include'),'tests/intinf/gmp-division.c',
                 str(prefix/'lib/libgmp.a'),*shlex.split(config['ldflags']),'-lm','-o',str(binary)],
                [*shlex.split(config['runner']),str(binary)]]
    streams = []
    for i,command in enumerate(commands):
        run = subprocess.run(command,capture_output=True,text=True,timeout=120)
        (out/f'{platform}-{i}.command.json').write_text(json.dumps(command)+'\n')
        (out/f'{platform}-{i}.stdout').write_text(run.stdout)
        (out/f'{platform}-{i}.stderr').write_text(run.stderr)
        assert run.returncode==0,(platform,run.returncode,run.stdout,run.stderr)
        streams.append({'stdout':run.stdout,'stderr':run.stderr})
    results[platform] = {'result':'pass','commands':commands,'streams':streams,
        'dependency':record,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest()}
    print(platform,'pinned division regression passes',flush=True)
(out/'report.json').write_text(json.dumps(results,indent=2)+'\n')
