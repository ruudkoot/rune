from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();p=root/'tests/out/benchmarks/gamteb-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/real/gamteb'
for local,public in [('math.sml','nofib-gamteb-math.sml'),('tables.sml','nofib-gamteb-tables.sml'),('kernel.sml','nofib-gamteb.sml'),('driver.sml','nofib-gamteb-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('gamteb-')for r in rows)
sources=['input','lazy','suspend','stream','nofib-gamteb-math','nofib-gamteb-tables','nofib-gamteb','nofib-gamteb-driver']
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='gamteb-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','observer','*.rbc'))
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchGamtebFn (Bench{policy})
  structure Driver = BenchGamtebDriverFn (Kernel)
  val run = Driver.run
end
''')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,repeats,n,count in [('smoke',1,100,118),('normal',200,1000,1231),('large',200,5000,5913)]:
  shutil.copy(p/(str(n)+'.reference'),dest/(profile+'.reference'))
  (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*count}\n')
  rows.append(dict(zip(fields,[name,profile,'nofib','real/gamteb',f'{repeats} {n} {profile}.reference',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'numerical,randomness,lists-streams,arrays,allocation-lifetimes,'+mode,profile+'.reference','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/gamteb';data.mkdir()
for n in [1,2,3,10,100,1000,5000]:
 for suffix in ['reference','results','stats']:shutil.copy(p/(str(n)+'.'+suffix),data/(str(n)+'.'+suffix))
shutil.copy(p/'math.references',data/'math.references')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
notice=(p/'source/GamtebMain.hs').read_text().split('module GamtebMain')[0]
header='(*\n'+'\n'.join(line[2:]if line.startswith('--')else line for line in notice.splitlines())+'\n*)\n'
(root/'tests/benchmarks/gamteb-tests.sml').write_text(header+s)
s=(p/'host-pilot.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
s=s.replace('  val base=""','  val mode="Need"\n  val base=""',1)
at=s.index('structure PilotStrict=')
s=s[:at]+s[at:].replace('  val base=""','  val mode="Strict"\n  val base=""',1)
s=s.replace('"gamteb/results-"','"gamteb/"^mode^"/results-"').replace('"gamteb/stats-"','"gamteb/"^mode^"/stats-"').replace('^" OK\\n"','^" checked\\n"')
(root/'tests/benchmarks/gamteb-kernel-tests.sml').write_text(header+s)
script='''#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/gamteb-checks.XXXXXX")
configs=CONFIGS_DEFAULT
for file in tests/benchmarks/data/gamteb/*; do basename "$file"; done > "$out/data.txt"
status=0
for part in kernel checker; do
  {
    for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/nofib-gamteb-math.sml examples/benchmarks/shared/nofib-gamteb-tables.sml examples/benchmarks/shared/nofib-gamteb.sml; do
      printf '%s\\n' "$root/$source"
    done
    if [ "$part" = checker ]; then
      printf '%s\\n' "$root/examples/benchmarks/shared/nofib-gamteb-driver.sml" "$root/tests/benchmarks/gamteb-tests.sml"
    else
      printf '%s\\n' "$root/tests/benchmarks/gamteb-kernel-tests.sml"
    fi
    printf '%s\\n' "$root/tests/basis/finish.sml"
  } > "$out/sources-$part.txt"
  for level in 0 2; do
    RUNE_MATRIX_RUN="$out/worker-$part-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \\
      sh tests/basis/run-matrix.sh --configs "$configs" \\
        --program-list "$out/sources-$part.txt" --program-data "$root/tests/benchmarks/data/gamteb" \\
        --program-data-list "$out/data.txt" --program-out "$out/$part-O$level" < /dev/null > "$out/$part-O$level.log" 2>&1 || { cat "$out/$part-O$level.log"; status=1; }
  done
done
if [ "$status" != 0 ]; then echo "bench-gamteb: validation failures ($out)" >&2; exit 1; fi
echo "bench-gamteb: raw streams, source physics, numerical checks and demand checks hold ($out)"
'''
script=script.replace('CONFIGS_DEFAULT',chr(36)+'{BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}')
(root/'tests/benchmarks/check-gamteb.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-gamteb-parallel.'").replace("{'atom-lazy','atom-strict'}","{'gamteb-lazy','gamteb-strict'}")
(p/'check-parallel.py').write_text(s)
variants=[
 ('inLML/gamteb.m','gamteb-lml','LML','historical functional implementation','Patricia Fasel','defer','legacy Float primitive precision/semantics and generated .t interfaces are not supplied; reconsider with a pinned LML runtime definition and reproducible numeric fixtures; retain all associated .m modules','author headers; no separate individual redistribution grant stated'),
 ('inLML/gamteb.m.97','gamteb-lml-097','LML 0.97','historical traced functional implementation','not stated in .97 headers','defer','explicit FloatAdd/Sub/Mul/Div primitives, missing generated .t interfaces and unknown Float precision prevent a faithful numeric baseline; reconsider with pinned primitive semantics and reference fixtures; distinct trace threading and fixed 320-particle input retained','no separate notice stated in .97 files; do not infer another variants grant'),
 ('inLML/gamteb_id.id','gamteb-id','Id','historical dataflow implementation','not stated','defer','original dataflow array construction/runtime and build setup are unavailable; reconsider with complete pinned dependencies or equivalent facilities under a separate feature roadmap; exp is approximated as 2.71828^x','no separate notice stated; do not infer the Haskell grant'),
 ('inFortran/gamteb.f','gamteb-fortran','Fortran 77','historical imperative reference','Buck Thompson (received original, per header); later authors unstated','exclude','historical foreign-language reference outside the initial SML/Haskell/OCaml executable import set; retain as an additional coverage candidate; explicit mutable transport state and affine grand RNG are not declared equivalent to the Haskell implementation','Regents of the University of California 1986 public copying/use notice, retained in file'),
 ('inFortran/gamo.f','gamo-fortran','Fortran 77','historical scalar reference','Buck Thompson (received original, per header); later authors unstated','exclude','historical foreign-language reference outside the initial language-family executable set; retain as a distinct candidate, with 100*scale particles and multiplicative mod-4194304 rannum rather than the Haskell binary-split affine generator','Regents of the University of California 1986 public copying/use notice, retained in file'),
 ('inLML/gamteb_for.f','gamteb-fortran-lml-reference','Fortran 77','historical comparison reference','Buck Thompson (received original, per header); later authors unstated','exclude','historical foreign-language reference, retained for provenance and future candidate review; one*scale input, recursive source splitting and extra instrumentation are not declared duplicates of another version; not selected by nofib Makefile','Regents of the University of California 1986 public copying/use notice, retained in file'),
 ('inFortran/fact.f','fact-fortran','Fortran','fixed recursion experiment','not stated','exclude','standalone fixed n=5 recursive factorial experiment without a nofib workload/build entry; not part of photon transport; retain source as historical support','no separate notice stated'),
 ('inLML/gamteb.doc','gamteb-lml-callgraph','text','historical call graph','not stated','exclude','documentation of source call relationships, not an executable workload','no separate notice stated'),
 ('inLML/libroutines','gamteb-lml-symbol-list','text','historical library symbol listing','not stated','exclude','archive member-name listing rather than library implementations; records primitive names but supplies no numeric semantics or executable workload','no separate notice stated')]
f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;rows=list(r)
for path,name,language,role,authors,disposition,reason,notices in variants:
 source=up/path
 rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','real/gamteb','real/gamteb/'+path,name,language,role,authors,hashlib.sha256(source.read_bytes()).hexdigest(),disposition,reason,notices])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
