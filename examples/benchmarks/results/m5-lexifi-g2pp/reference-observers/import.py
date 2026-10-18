from pathlib import Path
import csv,json,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/lexifi-g2pp-originals'
name='lexifi-g2pp';dest=suite/name;dest.mkdir()
parts=['date','math','random','optimization','calibration','input','check','driver']
for part in parts[:6]:shutil.copy(p/(part+'.sml'),suite/'shared'/('lexifi-g2pp-'+part+'.sml'))
check,driver=(p/'check.sml').read_text().split('structure BenchG2Driver=',1)
(suite/'shared/lexifi-g2pp-check.sml').write_text(check)
(suite/'shared/lexifi-g2pp-driver.sml').write_text('structure BenchG2Driver='+driver)
assert check+'structure BenchG2Driver='+driver==(p/'check.sml').read_text()

# Keep original source/data/build/notices, without any compiler outputs.
(dest/'upstream').mkdir()
for file in(p/'source').iterdir():
 if file.name in ['COPYING','README.txt','dune','lexifi-g2pp-bench.output']or file.name in [x+y for x in ['date','math','optimization','g2pp_calibration','main']for y in ['.ml','.mli']]:
  shutil.copy(file,dest/'upstream'/file.name)
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
for profile in ['smoke','normal','large']:shutil.copy(p/(profile+'.reference'),dest/(profile+'.reference'))
(dest/'benchmark.sml').write_text('''structure Benchmark=struct
 val name="lexifi-g2pp"
 fun run[limitText,path]=
   let val limit=BenchInput.between(1,20000)(BenchInput.integer limitText)
   in BenchG2Driver.run limit path end
 |run _=raise Fail"expected optimizer evaluation budget and reviewed reference"
end
''')
profiles=[('smoke',40,30,1048576),('normal',2000,600,4194304),('large',20000,3600,8388608)]
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']==name for r in rows)
sources=['shared/input.sml','shared/ocaml-random.sml']+['shared/lexifi-g2pp-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
for profile,limit,seconds,memory in profiles:
 (dest/(profile+'.expected')).write_text(str(limit)+':196\n')
 rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/lexifi-g2pp/main.exe',str(limit)+' '+profile+'.reference',name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'numerical,optimization,closures,arrays,floating-point,random-seed,library-replacement',profile+'.reference','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
pinned=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='sandmark')
identities={str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted((dest/'upstream').iterdir())}
identities.update({str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted(dest.glob('*.reference'))})
(dest/'SOURCE-IDENTITIES.json').write_text(json.dumps(dict(revision=pinned,files=identities),indent=2)+'\n')
for file in ['support-tests','de-tests','check-tests']:shutil.copy(p/(file+'.sml'),root/'tests/benchmarks'/('lexifi-g2pp-'+file+'.sml'))
data=root/'tests/benchmarks/data/lexifi-g2pp';data.mkdir()
shutil.copy(p/'smoke.reference',data/'smoke.reference')
# Explicit reviewed source/data order for the thin shell target.
script='#!/bin/sh\nset -eu\ncd "$(dirname "$0")/../.."\nroot=$(pwd)\nmkdir -p "$root/tests/out/benchmarks"\nout=$(mktemp -d "$root/tests/out/benchmarks/lexifi-g2pp-checks.XXXXXX")\nfor source in tests/basis/harness.sml examples/benchmarks/shared/ocaml-random.sml examples/benchmarks/shared/lexifi-g2pp-date.sml examples/benchmarks/shared/lexifi-g2pp-math.sml examples/benchmarks/shared/lexifi-g2pp-random.sml examples/benchmarks/shared/lexifi-g2pp-optimization.sml examples/benchmarks/shared/lexifi-g2pp-calibration.sml examples/benchmarks/shared/lexifi-g2pp-input.sml examples/benchmarks/shared/lexifi-g2pp-check.sml examples/benchmarks/shared/lexifi-g2pp-driver.sml tests/benchmarks/lexifi-g2pp-support-tests.sml tests/benchmarks/lexifi-g2pp-de-tests.sml tests/benchmarks/lexifi-g2pp-check-tests.sml tests/basis/finish.sml; do\n  printf \'%s\\n\' "$root/$source"\ndone > "$out/sources.txt"\nfor file in smoke.reference; do printf \'%s\\n\' "$file"; done > "$out/data.txt"\nstatus=0\nfor level in 0 2; do\n  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \\\n    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \\\n      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/lexifi-g2pp" \\\n      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }\ndone\nif [ "$status" != 0 ]; then echo "bench-lexifi-g2pp: validation failures ($out)" >&2; exit 1; fi\necho "bench-lexifi-g2pp: source calibration prices, optimizer traces and numerical controls hold ($out)"\n'
(root/'tests/benchmarks/check-lexifi-g2pp.sh').write_text(script)
script=(p.parent/'stdlib-text-originals/check-parallel.py').read_text();a=script.index("if row['benchmark']in");b=script.index("and row['profile']",a);script=script[:a]+"if row['benchmark']in{'lexifi-g2pp'}"+script[b:]
(p/'check-parallel.py').write_text(script.replace('final-stdlib-text-parallel.','final-lexifi-g2pp-parallel.'))
print('Imported LexiFi G2++ with original normal budget and three profiles')
