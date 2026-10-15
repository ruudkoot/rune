#!/usr/bin/env python3
"""Record the source/flags needed to relink the installed register runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
from runtime_inputs import executable_path, runtime_inputs

p = argparse.ArgumentParser()
p.add_argument('--vm',required=True)
p.add_argument('--cc',required=True)
p.add_argument('--cflags',required=True)
p.add_argument('--ldlibs',default='-lm')
p.add_argument('--config',required=True)
p.add_argument('--out',required=True)
p.add_argument('--sources',nargs='+',required=True)
p.add_argument('--headers',nargs='+',required=True)
a=p.parse_args()
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
config=Path(a.config)
configuration=json.loads((config/'config.json').read_text())
inputs=runtime_inputs(shlex.split(a.cc),shlex.split(a.cflags),configuration['cppflags'],
                      config/'config.h',a.sources,a.headers)
record={'vm_file':str(executable_path(a.vm)), 'vm_sha256':sha(executable_path(a.vm)),'configuration':configuration,
        'cc':shlex.split(a.cc),'cflags':shlex.split(a.cflags),'ldlibs':shlex.split(a.ldlibs),
        'sources':a.sources,'headers':a.headers,
        'source_hashes':{f:sha(f) for f in inputs}}
Path(a.out).write_text(json.dumps(record,indent=2)+'\n')
