from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/lambda-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/spectral/lambda'
for local,public in[('kernel.sml','nofib-lambda.sml'),('driver.sml','nofib-lambda-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('lambda-')for r in rows)
for style in ['simple','monad']:
 for mode,policy in [('lazy','Need'),('strict','Strict')]:
  name='lambda-'+style+'-'+mode;dest=suite/name;dest.mkdir()
  if name=='lambda-simple-lazy':shutil.copytree(up,dest/'upstream')
  (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
  (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchLambdaFn (Bench{policy})
  structure Driver = BenchLambdaDriverFn (Kernel)
  val run = Driver.run "{style}"
end
''')
  for profile,repeats,n in [('smoke',1,80),('normal',100,260),('large',100,550)]:
   value=n*(n+1)//2;result=('Con '+str(value)+'\n')if style=='simple'else str(value)+'  []\n'
   (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*len(result)}\n')
   sources=['input','lazy','suspend','nofib-lambda','nofib-lambda-driver']
   rows.append(dict(zip(fields,[name,profile,'nofib','spectral/lambda',f'{repeats} {n}',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'symbolic-search,higher-order,parsing,'+mode,'-','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/lambda';data.mkdir();shutil.copy(p/'terms.reference',data/'terms.reference')
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/lambda-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text().replace('fft2','lambda').replace('examples/benchmarks/shared/stream.sml ','').replace('source transforms, numerical bounds, quoted output and demand checks hold','source term/environment cases, interpreter transcripts and demand checks hold')
(root/'tests/benchmarks/check-lambda.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-lambda-parallel.'").replace("{'atom-lazy','atom-strict'}","{'lambda-simple-lazy','lambda-simple-strict','lambda-monad-lazy','lambda-monad-strict'}")
(p/'check-parallel.py').write_text(text)
print('Lambda imported; suite 360 programs /1072 profiles')
