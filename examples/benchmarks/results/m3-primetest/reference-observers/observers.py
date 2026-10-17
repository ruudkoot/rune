from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'source'
code=(d/'Prime.lhs').read_text();assert '> module Prime (multiTest) where'in code
(d/'KernelPrime.lhs').write_text(code.replace('> module Prime (multiTest) where','> module KernelPrime where'))
(d/'Observer.hs').write_text('''module Main where
import KernelPrime
import MyRandom
import IntLib
import System.Environment
emit label state number=do
 let (passed,after)=multiTest 100 state number
 putStrLn(label++" "++show number++" "++(if passed then "1"else"0")++" "++unwords(map show(take 4 after)))
 return after
walk _ state []=return ()
walk i state (n:ns)=do
 after<-emit(show i)state n
 walk(i+1)after ns
main=do
 [file]<-getArgs
 text<-readFile file
 putStrLn("raw "++unwords(map show(take 16(randomInts 111 47))))
 walk(0::Int)(randomInts 111 47)(map readInteger(lines text))
''')
with(d/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
(p/'small-cases.input').write_text('\n'.join(map(str,[-1,0,1,2,3,4,5,9,17,25,341,561,1105,2047,65537]))+'\n')
rows=[]
for name,file in [('small','small-cases.input'),('fast','source/primetest.faststdin')]:
 raw=subprocess.check_output([str(d/'observer'),str(p/file)],cwd=d,timeout=180);(p/(name+'.observe')).write_bytes(raw);rows.append(dict(name=name,lines=len(raw.splitlines())))
print(json.dumps(rows,indent=2))
