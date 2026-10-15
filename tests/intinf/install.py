#!/usr/bin/env python3
"""Stage, relocate, relink and remove an enabled or disabled installation."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser()
p.add_argument('--mode',choices=['gmp','sml'],required=True)
p.add_argument('--out',required=True)
a=p.parse_args();os.chdir(ROOT)
out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith(('RUNEVM_','RUNEOPT_')) and k!='RUNE_GC_STRESS'}
records=[]

def run(command,cwd=ROOT,expected=0):
    command=list(map(str,command));index=len(records)
    result=subprocess.run(command,cwd=cwd,env=env,capture_output=True,text=True,timeout=180)
    record={'argv':command,'cwd':str(cwd),'exit':result.returncode}
    records.append(record)
    (out/f'{index:03d}.stdout').write_text(result.stdout)
    (out/f'{index:03d}.stderr').write_text(result.stderr)
    (out/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
    assert result.returncode==expected,(command,result.returncode,result.stdout,result.stderr)
    return result.stdout,result.stderr

stage=out/'stage'
run(['sh',ROOT/'scripts/install.sh','--prefix','/opt/rune','--destdir',stage],cwd=out)
installed=out/'relocated tree'
assert not installed.exists(),'use a fresh output directory for each install check'
shutil.move(stage/'opt/rune',installed)
info=json.loads((installed/'lib/rune/rebuild/build-info.json').read_text())
assert info['configuration']['enabled']==(a.mode=='gmp')
rebuild=installed/'lib/rune/rebuild'
assert (rebuild/'runtime/intinf.c').is_file()
assert (rebuild/'build/deps/downloads/gmp-6.3.0.tar.xz').exists()==(a.mode=='gmp')
source=out/'arithmetic.sml'
source.write_text('''fun fact (0,acc) = acc
  | fact (n,acc) = fact(n-1,IntInf.*(IntInf.fromInt n,acc))
val () = print(IntInf.toString(fact(75,IntInf.fromInt 1)) ^ "\\n")
''')
expected=str(math.factorial(75))+'\n'
program=out/'arithmetic.rbc'
run([installed/'bin/rune','-o',program,source],cwd=out)
for mode in (['gmp','sml'] if a.mode=='gmp' else ['auto','sml']):
    stdout,_=run([installed/'bin/runevm','--intinf='+mode,program],cwd=out)
    assert stdout==expected
if a.mode=='sml':
    _,stderr=run([installed/'bin/runevm','--intinf=gmp',program],cwd=out,expected=2)
    assert 'requested GMP backend is unavailable' in stderr
if (installed/'bin/runeopt').exists():
    stack=out/'arithmetic-stack.rbc';native=out/'arithmetic-native'
    run([installed/'bin/rune','--target=stack','-o',stack,source],cwd=out)
    run([installed/'bin/runeopt',stack,'-o',native],cwd=out)
    stdout,_=run([native],cwd=out);assert stdout==expected
relinked=out/'runevm-relinked'
run(['python3',rebuild/'rebuild.py',relinked],cwd=out)
stdout,_=run([relinked,'--intinf='+a.mode,program],cwd=out);assert stdout==expected
if a.mode=='gmp':
    header=rebuild/'gmp/include/gmp.h'; original=header.read_bytes()
    try:
        header.write_bytes(original+b'\n/* altered installation probe */\n')
        _,stderr=run(['python3',rebuild/'rebuild.py',out/'rejected-relink'],cwd=out,expected=1)
        assert 'differs from its provisioning record' in stderr
        assert not (out/'rejected-relink').exists()
    finally:
        header.write_bytes(original)
version,_=run([installed/'bin/runevm','--version'],cwd=out)
marker=installed/'bin/unrelated-marker';marker.write_text('keep\n')
run(['sh',ROOT/'scripts/install.sh','--prefix',installed,'--uninstall'],cwd=out)
assert marker.read_text()=='keep\n'
assert not (installed/'bin/rune').exists() and not (installed/'lib/rune').exists()
(out/'report.json').write_text(json.dumps({'mode':a.mode,'result':'pass','commands':records,
    'version':version,'build_info':info,'relinked_sha256':hashlib.sha256(relinked.read_bytes()).hexdigest()},indent=2)+'\n')
print(a.mode,'staged install, relocation, native output, relinking and uninstall pass')
