from pathlib import Path
import csv,json,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/minilight-originals';dest=suite/'minilight';dest.mkdir()
parts=['vector','parse','delay','random','triangle','spatial','scene','surface','ray','image','camera','check']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('minilight-'+part+'.sml'))
(dest/'upstream').mkdir()
for file in(p/'source').iterdir():
 if file.suffix=='.ml'or file.name in ['LICENSE.txt','OMakefile','OMakeroot','dune','roomfront.ml.txt']:shutil.copy(file,dest/'upstream'/file.name)
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
(dest/'benchmark.sml').write_text('''structure Benchmark=struct
 val name="minilight"
 fun run[model,reference]=BenchMiniCheck.run model reference
 |run _=raise Fail"expected MiniLight model and reviewed image reference"
end
''')
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']=='minilight'for r in rows)
sources=['shared/input.sml','shared/ocaml-random.sml']+['shared/minilight-'+part+'.sml'for part in parts]+['minilight/benchmark.sml','shared/main.sml']
for profile,frames,w,h,seconds,memory in [('smoke',1,8,5,30,1048576),('normal',2,81,50,600,4194304),('large',4,162,100,3600,8388608)]:
 for suffix in ['.model','.reference']:shutil.copy(p/(profile+suffix),dest/(profile+suffix))
 (dest/(profile+'.expected')).write_text(str(frames)+':'+str(w*h)+':'+str(1 if frames==1 else 2)+'\n')
 rows.append(dict(zip(fields,['minilight',profile,'sandmark','benchmarks/multicore-minilight/sequential/minilight.exe',profile+'.model '+profile+'.reference','minilight/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'rendering,geometry,arrays,memoization,closures,random-seed,numerical,allocation',profile+'.model,'+profile+'.reference','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
identities={str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted((dest/'upstream').iterdir())}
identities.update({str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted(dest.glob('*.model'))})
(dest/'SOURCE-IDENTITIES.json').write_text(json.dumps(identities,indent=2)+'\n')
shutil.copy(p/'tests.sml',root/'tests/benchmarks/minilight-tests.sml')
data=root/'tests/benchmarks/data/minilight';data.mkdir()
for file in ['smoke.model','smoke.reference']:shutil.copy(p/file,data/file)
# Explicit reviewed source/data order for the thin shell target.
script='#!/bin/sh\nset -eu\ncd "$(dirname "$0")/../.."\nroot=$(pwd)\nmkdir -p "$root/tests/out/benchmarks"\nout=$(mktemp -d "$root/tests/out/benchmarks/minilight-checks.XXXXXX")\nfor source in tests/basis/harness.sml examples/benchmarks/shared/ocaml-random.sml examples/benchmarks/shared/minilight-vector.sml examples/benchmarks/shared/minilight-parse.sml examples/benchmarks/shared/minilight-delay.sml examples/benchmarks/shared/minilight-random.sml examples/benchmarks/shared/minilight-triangle.sml examples/benchmarks/shared/minilight-spatial.sml examples/benchmarks/shared/minilight-scene.sml examples/benchmarks/shared/minilight-surface.sml examples/benchmarks/shared/minilight-ray.sml examples/benchmarks/shared/minilight-image.sml examples/benchmarks/shared/minilight-camera.sml examples/benchmarks/shared/minilight-check.sml tests/benchmarks/minilight-tests.sml tests/basis/finish.sml; do\n  printf \'%s\\n\' "$root/$source"\ndone > "$out/sources.txt"\nfor file in smoke.model smoke.reference; do printf \'%s\\n\' "$file"; done > "$out/data.txt"\nstatus=0\nfor level in 0 2; do\n  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \\\n    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \\\n      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/minilight" \\\n      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }\ndone\nif [ "$status" != 0 ]; then echo "bench-minilight: validation failures ($out)" >&2; exit 1; fi\necho "bench-minilight: source render snapshots, random state, identity and demand checks agree ($out)"\n'
(root/'tests/benchmarks/check-minilight.sh').write_text(script)
print('Imported sequential MiniLight with original scene, exact random-state and first/last image checks')
