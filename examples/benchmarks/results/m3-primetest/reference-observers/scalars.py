from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'source';n=int((p/'mersenne.input').read_text())
cases=[(0,0,0),(2,0,1),(2,1,7),(2,10,17),(-3,13,97),(7,111,341),(12345678901234567890,12345,n),(2**200+7,1111,n)]
(d/'Scalars.hs').write_text('''module Main where
import IntLib
emit(a,b,m)=putStrLn(unwords(map show[a,b,m,powerMod a b m]))
main=mapM_ emit '''+repr(cases).replace('),', '),')+'\n')
with(d/'scalars-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','scalars','Scalars.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(d/'scalars')],cwd=d,timeout=60);(p/'scalar-powers.data').write_bytes(raw)
for line in raw.decode().splitlines():
 a,b,m,value=map(int,line.split());assert value==(1 if b==0 else pow(a,b,m))
(p/'scalar-metadata.json').write_text(json.dumps(dict(cases=len(cases),large_modulus_bits=n.bit_length(),scope='Exact GHC source powerMod and independent Python pow; source exponent-zero shortcut retained including modulus zero/one'),indent=2)+'\n')
print('Eight exact modular-power cases agree, including two 607-bit moduli')
