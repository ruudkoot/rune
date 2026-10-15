#!/usr/bin/env python3
"""Check finite policy boundaries without allocating extreme-sized values."""
import argparse
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--vm',default='bin/runevm')
a = p.parse_args()
out = root/'tests/out/intinf/options';out.mkdir(parents=True,exist_ok=True)
vm = str((root/a.vm).resolve())
count = 0
for flag,value,valid in [
    ('--intinf-max-bits','64',True),('--intinf-max-bits','1073741822',True),
    ('--intinf-max-bits','63',False),('--intinf-max-bits','1073741823',False),
    ('--intinf-max-bits','0',False),('--intinf-max-bits','-1',False),
    ('--intinf-max-bits','18446744073709551616',False),
    ('--intinf-gmp-memory','1',True),('--intinf-gmp-memory','0',False),
    ('--intinf-gmp-memory','-1',False),('--intinf-gmp-memory','1x',False)]:
    count += 1
    command = [vm,flag,value,'--version']
    result = subprocess.run(command,capture_output=True,timeout=10)
    prefix=out/(Path(vm).name+'-'+str(count))
    prefix.with_suffix('.command.json').write_text(json.dumps(command)+'\n')
    prefix.with_suffix('.stderr').write_bytes(result.stderr)
    assert result.returncode == (0 if valid else 2),(command,result.stderr)
print(f'IntInf option bounds: {count} checks pass')
