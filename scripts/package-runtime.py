#!/usr/bin/env python3
"""Retain runtime relinking inputs and the selected GMP dependency provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from runtime_inputs import executable_path

ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def require(condition,message):
    if not condition:raise SystemExit('package-runtime: '+message)

p=argparse.ArgumentParser()
p.add_argument('--vm',default=str(ROOT/'bin/runevm'))
p.add_argument('--build-info',default=str(ROOT/'build/gmp/native-build.json'))
p.add_argument('--out',required=True)
a=p.parse_args()
record=json.loads(Path(a.build_info).read_text())
vm=executable_path(a.vm)
require(sha(vm)==record['vm_sha256'],'VM differs from its build record; rebuild before installing')
for name,digest in record['source_hashes'].items():
    require(sha(ROOT/name)==digest, f'runtime source differs from its build record: {name}')
config=record['configuration']
version=subprocess.check_output([str(vm.resolve()),'--version'],text=True)
require(('GMP headers ' in version)==config['enabled'],'VM and dependency configuration disagree')
if config['enabled']:
    expected=f"GMP headers {config['header_version']}, library {config['library_version']}, {config['limb_bits']}-bit limbs, supported\n"
    require(expected in version,'GMP version changed; reconfigure and rebuild before installing')
prefix=(ROOT/config['prefix']).resolve() if config['prefix'] else None
if config['enabled'] and prefix:
    for kind,name in [('header','include/gmp.h'),('library','lib/libgmp.a')]:
        require(sha(prefix/name)==config[kind+'_sha256'],f'changed GMP {kind}')
dependency=config.get('dependency')
archive=None
if config['enabled'] and dependency:
    archive=ROOT/'build/deps/downloads'/('gmp-'+dependency['config']['version']+'.tar.xz')
    require(sha(archive)==dependency['config']['sha256'],'missing or modified pinned source archive')
    require(sha(ROOT/'scripts/build-gmp.py')==dependency['config']['recipe_sha256'],'GMP recipe differs from its build record')
out=Path(a.out).resolve();out.parent.mkdir(parents=True,exist_ok=True)
temporary=Path(tempfile.mkdtemp(prefix='.rebuild-',dir=out.parent))
try:
    for name in record['source_hashes']:
        target=temporary/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/name,target)
    for name in ['configure-gmp.py','build-gmp.py']:
        target=temporary/'scripts'/name;target.parent.mkdir(exist_ok=True)
        shutil.copyfile(ROOT/'scripts'/name,target)
    for name in ['LICENSE','COPYING']:
        if (ROOT/name).is_file():shutil.copyfile(ROOT/name,temporary/name)
    if config['enabled'] and prefix:
        for name in ['include/gmp.h','lib/libgmp.a','rune-gmp.json']:
            if (prefix/name).exists():
                target=temporary/'gmp'/name;target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(prefix/name,target)
        notices=prefix/'share/licenses/gmp'
        if notices.is_dir():shutil.copytree(notices,temporary/'gmp/notices')
    if archive:
        target=temporary/'build/deps/downloads'/archive.name
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(archive,target)
    (temporary/'build-info.json').write_text(json.dumps({**record,'version':version},indent=2)+'\n')
    (temporary/'rebuild.py').write_text('''#!/usr/bin/env python3
import json,os,shlex,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parent;os.chdir(root)
r=json.loads((root/'build-info.json').read_text());enabled=r['configuration']['enabled']
prefix='gmp' if enabled and (root/'gmp/include/gmp.h').exists() else ''
subprocess.run([sys.executable,'scripts/configure-gmp.py','--mode','yes' if enabled else 'no',
               '--prefix',prefix,'--cc',shlex.join(r['cc']),'--cflags='+shlex.join(r['cflags']),
               '--out','build/config'],check=True)
c=json.loads(Path('build/config/config.json').read_text())
command=[*r['cc'],*r['cflags'],'-Iruntime',*c['cppflags'],'-include','build/config/config.h',
         '-o',sys.argv[1] if len(sys.argv)>1 else 'runevm-relinked',*r['sources'],*c['ldlibs'],*r['ldlibs']]
subprocess.run(command,check=True)
''')
    (temporary/'README').write_text('''Runtime relinking material

Copy this directory to a writable location and run python3 rebuild.py.
The result is runevm-relinked; it uses the preserved runtime source and flags.
This is a source rebuild, not a promise of byte-identical machine code.
The original build and binary hashes are in build-info.json.

For pinned GMP, gmp/ includes the header, static library, provenance and notices;
build/deps/downloads/ contains the checksum-pinned source archive and scripts/
contains the exact provisioning recipe. To rebuild it, run scripts/build-gmp.py
with --prefix gmp and the platform/options from gmp/rune-gmp.json (including
--enable-fat, --abi, --with-pic or --disable-assembly where recorded).
Upstream tests must pass before installation. A compiler and any cross sysroot
or runner named in the record are external build requirements.

For a changed GMP library, regenerate its provisioning record with the recipe,
or use a checked local prefix without a stale rune-gmp.json. The runtime
configuration step rejects files that disagree with their recorded hashes.
A system GMP installation has no supplied source/build provenance; its checked
configuration is recorded explicitly and its development package is required
for relinking. No pinned-source claim is made for that case.
''')
    if out.exists():shutil.rmtree(out)
    temporary.replace(out)
finally:
    if temporary.exists():shutil.rmtree(temporary)
print('retained runtime build and dependency material in',out)
