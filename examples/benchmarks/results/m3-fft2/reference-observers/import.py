from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();p=root/'tests/out/benchmarks/fft2-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/spectral/fft2'
for local,public in [('kernel.sml','nofib-fft2.sml'),('driver.sml','nofib-fft2-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('fft2-')for r in rows)
sources=['input','lazy','suspend','stream','nofib-fft2','nofib-fft2-driver']
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='fft2-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchFFT2Fn (Bench{policy})
  structure Driver = BenchFFT2DriverFn (Kernel)
  val run = Driver.run
end
''')
 for profile,samples,base in [('smoke',1,70),('normal',100,245),('large',100,490)]:
  shutil.copy(p/(profile+'.reference'),dest/(profile+'.reference'))
  (dest/(profile+'.expected')).write_text(f'{samples}:{samples}\n')
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/fft2',f'{samples} {base} {profile}.reference',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'numerical,higher-order,lists-streams,'+mode,profile+'.reference','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/fft2';data.mkdir()
for pattern in ['*.reference','*.fft','*.fftinv','*.dft','*.dftinv','*.sft','*.sct']:
 for file in p.glob(pattern):shutil.copy(file,data/file.name)
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/fft2-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-gg.sh').read_text().replace('gg','fft2')
script=script.replace('examples/benchmarks/shared/finite-binary32.sml ','').replace('examples/benchmarks/shared/nofib-fft2-core.sml ','').replace('examples/benchmarks/shared/nofib-fft2-graphics.sml ','').replace('examples/benchmarks/shared/nofib-fft2-check.sml ','')
script=script.replace('source traces, graph modes, numeric PostScript checks and demand checks hold','source transforms, numerical bounds, quoted output and demand checks hold')
(root/'tests/benchmarks/check-fft2.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-fft2-parallel.'").replace("{'atom-lazy','atom-strict'}","{'fft2-lazy','fft2-strict'}")
(p/'check-parallel.py').write_text(text)
with(suite/'source-variants.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
for file,lang,author,role,reason in [
 ('fourier.m','Miranda','Rex Page','historical implementation','distinct Miranda functional reference remains outside the initial SML/Haskell/OCaml executable set; retain as a future candidate with its original environment and numeric semantics'),
 ('fourier.f','Fortran','Rex Page','historical implementation','distinct fixed-array Fortran program with default real/complex kinds and interactive size remains outside the initial SML/Haskell/OCaml executable set; retain as a future reference candidate'),
 ('fft.c','C','Matt Donadio','library fragment','iterative bit-reversal FFT fragment has no standalone driver, benchmark profiles or fixture; retain its distinct algorithm as contextual source rather than claim an exact duplicate')]:
 rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','spectral/fft2','spectral/fft2/'+file,Path(file).stem,lang,role,author,hashlib.sha256((up/file).read_bytes()).hexdigest(),'exclude',reason,'no separate redistribution notice stated in the individual file; preserve its complete attribution and correspondence'])))
with(suite/'source-variants.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
print('FFT2 imported: 356 programs /1060 profiles')
