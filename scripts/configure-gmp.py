#!/usr/bin/env python3
"""Check a local GMP installation and emit its build flags and provenance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

PROBE = r'''
#include <stdio.h>
#include <gmp.h>
int main(void) {
  unsigned major = 0, minor = 0, patch = 0;
  printf("%d.%d.%d\n%s\n%d\n%d\n%d\n", __GNU_MP_VERSION,
    __GNU_MP_VERSION_MINOR, __GNU_MP_VERSION_PATCHLEVEL, gmp_version,
    GMP_NUMB_BITS, mp_bits_per_limb, GMP_NAIL_BITS);
  /* Do not use arithmetic objects before the ABI/version checks. Python
     records and rejects unsupported metadata even when this returns 0. */
  if (__GNU_MP_VERSION < 6 || (__GNU_MP_VERSION == 6 && __GNU_MP_VERSION_MINOR < 3) ||
      sscanf(gmp_version, "%u.%u.%u", &major, &minor, &patch) != 3 ||
      major != __GNU_MP_VERSION || (major == 6 && minor < 3) ||
      GMP_NUMB_BITS != mp_bits_per_limb || GMP_NAIL_BITS != 0) return 0;
  mpz_t x; mpz_init_set_ui(x, 17); mpz_mul(x, x, x);
  if (mpz_cmp_ui(x, 289)) return 1;
  mpz_clear(x);
  return 0;
}
'''

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--mode', choices=('auto','yes','no'), required=True)
    p.add_argument('--cc', default='cc')
    p.add_argument('--cflags', default='')
    p.add_argument('--prefix', default='')
    p.add_argument('--out', required=True)
    p.add_argument('--runner', default='')
    a = p.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    record = {'mode':a.mode, 'cc':a.cc, 'cflags':a.cflags, 'prefix':a.prefix,
              'runner':a.runner, 'enabled':False}
    cpp = []; libs = []; reason = 'disabled by GMP=no'
    def run(command):
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or 'command failed: '+shlex.join(command))
        return result.stdout.strip()
    if a.mode != 'no':
        try:
            if a.prefix:
                prefix = Path(a.prefix).resolve()
                header = prefix/'include/gmp.h'; library = prefix/'lib/libgmp.a'
                for f in (header,library):
                    if not f.is_file(): raise RuntimeError('missing '+str(f))
                cpp = ['-I'+str(prefix/'include')]; libs = [str(library)]
                metadata = prefix/'rune-gmp.json'
                dependency = json.loads(metadata.read_text()) if metadata.exists() else None
                for label,f in [('header',header),('library',library)]:
                    digest = hashlib.sha256(f.read_bytes()).hexdigest()
                    record[label+'_sha256'] = digest
                    if dependency and digest != dependency[label+'_sha256']:
                        raise RuntimeError('GMP '+label+' differs from its provisioning record')
                record['dependency'] = dependency
                provenance = 'pinned '+dependency['config']['sha256'] if dependency else 'checked local prefix'
            else:
                try:
                    cpp = shlex.split(run(['pkg-config','--cflags','gmp']))
                    libs = shlex.split(run(['pkg-config','--libs','gmp']))
                    record['pkg_config_version'] = run(['pkg-config','--modversion','gmp'])
                except (OSError,RuntimeError,subprocess.TimeoutExpired):
                    cpp = []; libs = ['-lgmp']
                    record['pkg_config_version'] = None
                provenance = 'checked system installation; source and build options not supplied'
            (out/'probe.c').write_text(PROBE)
            command = [*shlex.split(a.cc),*shlex.split(a.cflags),*cpp,
                       str(out/'probe.c'),*libs,'-o',str(out/'probe')]
            record['probe_command'] = command
            run(command)
            fields = run([*shlex.split(a.runner),str((out/'probe').resolve())]).splitlines()
            h,l = (tuple(map(int,s.split('.'))) for s in fields[:2])
            record.update(header_version=fields[0],library_version=fields[1],
                          header_limb_bits=int(fields[2]),library_limb_bits=int(fields[3]),
                          nail_bits=int(fields[4]))
            if h < (6,3,0) or l < (6,3,0) or h[0] != l[0] or fields[2] != fields[3] or fields[4] != '0':
                raise RuntimeError('unsupported or mismatched GMP header/library: '+repr(fields))
            record.update(enabled=True,header_version=fields[0],library_version=fields[1],
                          limb_bits=int(fields[2]),nail_bits=int(fields[4]),provenance=provenance,
                          target=run([*shlex.split(a.cc),'-dumpmachine']),
                          compiler=run([*shlex.split(a.cc),'--version']).splitlines()[0])
            reason = provenance
        except (OSError,ValueError,KeyError,RuntimeError,subprocess.TimeoutExpired) as e:
            reason = str(e)
            if a.mode == 'yes':
                raise SystemExit('GMP=yes: '+reason)
            cpp = []; libs = []
    record['reason'] = reason
    (out/'config.json').write_text(json.dumps(record,indent=2)+'\n')
    options = record.get('dependency',{} ) or {}
    options = {'requested':options['config'], 'configured':options.get('configured',{})} if options else {'unknown':True}
    # json string escaping is also valid C string escaping for these ASCII metadata.
    (out/'config.h').write_text('#define RUNE_HAVE_GMP '+str(int(record['enabled']))+'\n'+
        '#define RUNE_GMP_PROVENANCE '+json.dumps(record.get('provenance',reason))+'\n'+
        '#define RUNE_GMP_TARGET '+json.dumps(record.get('target','unavailable'))+'\n'+
        '#define RUNE_GMP_OPTIONS '+json.dumps(json.dumps(options,sort_keys=True))+'\n')
    (out/'config.mk').write_text('GMP_CPPFLAGS := '+shlex.join(cpp)+'\nGMP_LDLIBS := '+shlex.join(libs)+'\n')
    print('GMP: '+('enabled: ' if record['enabled'] else 'SML fallback: ')+reason)

if __name__ == '__main__':
    main()
