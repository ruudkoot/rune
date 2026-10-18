from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent
(p/'source/ZeroProduct.hs').write_text('module Main where\nimport qualified RealM as R\nmain=print(R.evalReal(R.mulReal(R.int2Real 0)(R.int2Real 2))(-4))\n')
with(p/'zero-build.log').open('w')as log:subprocess.run(['ghc','-O2','-o','zero-product','ZeroProduct.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
(p/'zero-product.sml').write_text('''structure SymalgZeroProduct=struct
 structure N=BenchSymalgRealFn(BenchNeed)
 structure E=BenchSymalgRealFn(BenchStrict)
 val result=case CommandLine.arguments()of["need"]=>N.eval(N.multiply(N.fromInteger 0)(N.fromInteger 2))(~4)
   |["strict"]=>E.eval(E.multiply(E.fromInteger 0)(E.fromInteger 2))(~4)
   |_=>raise Fail"expected policy"
 val _=print(IntInf.toString result^"\\n")
end
''')
with(p/'zero-sml-build.log').open('w')as log:subprocess.run(['bin/rune','--lint','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml',str(p/'real.sml'),str(p/'zero-product.sml'),'-o',str(p/'zero-product.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for label,cmd in [('original',[str(p/'source/zero-product')]),('need',['bin/runevm',str(p/'zero-product.rbc'),'need']),('strict',['bin/runevm',str(p/'zero-product.rbc'),'strict'])]:
 try:r=subprocess.run(cmd,capture_output=True,timeout=3,preexec_fn=cap);status='exit-'+str(r.returncode);out=r.stdout;err=r.stderr
 except subprocess.TimeoutExpired as ex:status='timeout';out=ex.stdout or b'';err=ex.stderr or b''
 (p/('zero-'+label+'.stdout')).write_bytes(out);(p/('zero-'+label+'.stderr')).write_bytes(err)
 records.append(dict(policy=label,status=status,seconds_limit=3,memory_limit_bytes=1024**3))
 print(records[-1],flush=True)
(p/'zero-product-results.json').write_text(json.dumps(records,indent=2)+'\n')
assert all(r['status']=='timeout'for r in records)
