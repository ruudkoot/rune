from pathlib import Path
import csv,json,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/sauvola-originals';name='contrast';dest=suite/name;dest.mkdir()
for part in ['image','kernel','driver']:shutil.copy(p/(part+'.sml'),suite/'shared'/('contrast-'+part+'.sml'))
text=(p/'memo.sml').read_text()
a=text.index('functor BenchSauvolaMemoFn');b=text.index('structure BenchSauvolaRealMemo');c=text.index('structure BenchSauvolaIntMemo')
pieces={'hash':text[:a],'memo-table':text[a:b],'memo-real':text[b:c],'memo-int':text[c:]}
for part,source in pieces.items():(suite/'shared'/('contrast-'+part+'.sml')).write_text(source)
assert ''.join(pieces.values())==text
(dest/'upstream').mkdir()
for name in ['contrast.ml','LICENSE','Makefile','dune']:shutil.copy(p/'source'/name,dest/'upstream'/name)
lib=p/'camlimages/camlimages-5.0.4';(dest/'upstream-library').mkdir()
for name in ['License.txt','Changes.txt','README.md']:shutil.copy(lib/name,dest/'upstream-library'/name)
for name in ['color.ml','color.mli','rgb24.ml','rgb24.mli','genimage.ml','genimage.mli','bitmap.ml','bitmap.mli','oImages.ml','oImages.mli','ppm.ml','ppm.mli']:
 shutil.copy(lib/'core'/name,dest/'upstream-library'/name)
for source,target in [('dependency-archive.json','LIBRARY-ARCHIVE.json'),('input-identities.json','INPUT-IDENTITIES.json')]:shutil.copy(p/source,dest/target)
identities={'library_version':'5.0.4','files':{str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted((dest/'upstream-library').iterdir())}}
(dest/'DEPENDENCIES.json').write_text(json.dumps(identities,indent=2)+'\n')
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-library/** -text -whitespace\n')
sources=['shared/input.sml','shared/ocaml-stdlib-hash.sml']+['shared/contrast-'+part+'.sml'for part in ['image','hash','memo-table','memo-real','memo-int','kernel','driver']]+['contrast/benchmark.sml','shared/main.sml']
(dest/'benchmark.sml').write_text('''structure Benchmark=struct
 val name="contrast"
 fun run[image,referencePrefix]=BenchSauvolaDriver.run image referencePrefix
 |run _=raise Fail"expected PPM image and reviewed reference prefix"
end
''')
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']=='contrast'for r in rows)
for profile,w,h,seconds,memory in [('smoke',32,32,30,1048576),('normal',64,48,600,4194304),('large',267,200,3600,8388608)]:
 shutil.copy(p/(profile+'.ppm'),dest/(profile+'.ppm'));(dest/profile).mkdir()
 bits=sorted((p/'outputs'/profile).glob('*.bits'));assert len(bits)==8
 for file in bits:shutil.copy(file,dest/profile/file.name)
 (dest/(profile+'.expected')).write_text(str(w)+':'+str(h)+':8\n')
 data=[profile+'.ppm']+[profile+'/'+f.name for f in bits]
 rows.append(dict(zip(fields,['contrast',profile,'sandmark','benchmarks/sauvola/contrast.exe',profile+'.ppm '+profile+'/', 'contrast/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'image-processing,arrays,numerical,memoization,library-replacement,allocation',','.join(data),'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
for local,public in [('support-tests-final','contrast-support-tests'),('image-tests','contrast-image-tests')]:shutil.copy(p/(local+'.sml'),root/'tests/benchmarks'/(public+'.sml'))
data=root/'tests/benchmarks/data/contrast';shutil.copytree(p/'data',data)
# Explicit reviewed source/data order for the thin shell target.
script='#!/bin/sh\nset -eu\ncd "$(dirname "$0")/../.."\nroot=$(pwd)\nmkdir -p "$root/tests/out/benchmarks"\nout=$(mktemp -d "$root/tests/out/benchmarks/contrast-checks.XXXXXX")\nfor source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/ocaml-stdlib-hash.sml examples/benchmarks/shared/contrast-image.sml examples/benchmarks/shared/contrast-hash.sml examples/benchmarks/shared/contrast-memo-table.sml examples/benchmarks/shared/contrast-memo-real.sml examples/benchmarks/shared/contrast-memo-int.sml examples/benchmarks/shared/contrast-kernel.sml examples/benchmarks/shared/contrast-driver.sml tests/benchmarks/contrast-support-tests.sml tests/benchmarks/contrast-image-tests.sml tests/basis/finish.sml; do\n  printf \'%s\\n\' "$root/$source"\ndone > "$out/sources.txt"\nfor file in adaptive_contrast_spreading.bits niblack_global_gray.bits niblack_local_gray.bits niblack_local_monochrome.bits sauvola_global_gray.bits sauvola_global_monochrome.bits sauvola_local_gray.bits sauvola_local_monochrome.bits smoke.ppm; do printf \'%s\\n\' "$file"; done > "$out/data.txt"\nstatus=0\nfor level in 0 2; do\n  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \\\n    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \\\n      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/contrast" \\\n      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }\ndone\nif [ "$status" != 0 ]; then echo "bench-contrast: validation failures ($out)" >&2; exit 1; fi\necho "bench-contrast: source image rasters, tuple hashes and memoization checks agree ($out)"\n'
(root/'tests/benchmarks/check-contrast.sh').write_text(script)
print('Imported contrast with eight source pipelines and three fixed image profiles')
