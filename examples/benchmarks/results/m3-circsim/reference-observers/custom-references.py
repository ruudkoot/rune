from pathlib import Path
import subprocess,json,resource
p=Path(__file__).resolve().parent;d=p/'spectral'
(d/'Custom.hs').write_text('''module Main where
import Kernel
import System.Environment
rows n c = [[if t `mod` 3==1 then F else T]++[if (t*5+i*3+t `div` 2) `mod` 7<3 then T else F|i<-[0..n-1]]|t<-[0..c-1]]
main=do
 [b,c]<-getArgs
 let n=read b; count=read c; input=rows n count
 print input
 print(circuit_simulate input(pad_circuit(regs n)))
 print[xor a b|a<-[F,T],b<-[F,T]]
''')
with(d/'custom-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','custom','Custom.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
meta=[]
for n,c in [(1,8),(2,8),(3,9),(8,12),(16,5)]:
 raw=subprocess.check_output([str(d/'custom'),str(n),str(c)],cwd=d,timeout=30);(p/(f'custom-{n}-{c}.trace')).write_bytes(raw);lines=raw.decode().splitlines();assert lines[2]=='[T,F,F,T]'
 decode=lambda text:json.loads(text.replace('T','true').replace('F','false'))
 inputs=decode(lines[0]);actual=decode(lines[1]);state=[False]*n;expected=[]
 for row in inputs:
  expected.append(state[:]);state=row[1:]if row[0]else state
 assert expected==actual,(n,c,expected,actual)
 meta.append(dict(bits=n,cycles=c,register_model='output previous stored bits; load row payload when sto=T, hold when sto=F',source_xor_truth_table=lines[2]))
(p/'custom-metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print('PASS five varied register traces against independent hold/load model; source Xnor truth table confirmed')
