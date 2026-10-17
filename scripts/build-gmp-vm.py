#!/usr/bin/env python3
"""Check target GMP and atomically link a cross VM when its inputs change."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
from runtime_inputs import runtime_inputs

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--mode', choices=('auto', 'yes', 'no'), required=True)
    p.add_argument('--prefix', default='')
    p.add_argument('--cc', required=True)
    p.add_argument('--cflags', default='')
    p.add_argument('--ldlibs', default='-lm')
    p.add_argument('--runner', default='')
    p.add_argument('--config', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--windows', action='store_true')
    p.add_argument('--sources', nargs='+', required=True)
    p.add_argument('--headers', nargs='*', default=[])
    p.add_argument('--objects', nargs='*', default=[],
                   help='extra objects on the link line, such as a Windows icon resource')
    a = p.parse_args()
    os.chdir(ROOT)
    config = Path(a.config)
    target = Path(a.out)
    subprocess.run(['python3', str(ROOT/'scripts/configure-gmp.py'),
                    '--mode', a.mode, '--prefix', a.prefix, '--cc', a.cc,
                    '--cflags='+a.cflags, '--runner', a.runner, '--out', str(config)],
                   check=True)
    dependency = json.loads((config/'config.json').read_text())
    inputs = runtime_inputs(shlex.split(a.cc),shlex.split(a.cflags),dependency['cppflags'],
                            config/'config.h',a.sources,a.headers)
    inputs += [str(Path(__file__)),str(Path(__file__).with_name('runtime_inputs.py'))]
    inputs += list(a.objects)
    record = {'options': vars(a), 'inputs': {f: digest(f) for f in inputs},
              'configuration_sha256': digest(config/'config.json')}
    stamp = config/'linked.json'
    if stamp.exists() and target.exists():
        previous = json.loads(stamp.read_text())
        if previous.get('inputs') == record and previous.get('vm_sha256') == digest(target):
            print(f'{target}: verified unchanged cross build')
            return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name+'.tmp')
    command = [*shlex.split(a.cc), *shlex.split(a.cflags), '-Iruntime',
               *dependency['cppflags'], '-include', str(config/'config.h'),
               '-o', str(temporary), *a.sources, *a.objects, *dependency['ldlibs'],
               *shlex.split(a.ldlibs)]
    print(shlex.join(command), flush=True)
    try:
        subprocess.run(command, check=True)
        if a.windows:
            objdump = subprocess.check_output([*shlex.split(a.cc), '-print-prog-name=objdump'], text=True).strip()
            imports = subprocess.check_output([objdump, '-p', str(temporary)], text=True)
            dlls = re.findall(r'DLL Name: (\S+)', imports)
            if any(name.lower().startswith('lib') for name in dlls):
                raise RuntimeError(f'{target}: non-system DLL imports: {dlls}')
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    stamp.write_text(json.dumps({'inputs': record, 'command': command,
                                'vm_sha256': digest(target)}, indent=2)+'\n')


if __name__ == '__main__':
    main()
