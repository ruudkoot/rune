from pathlib import Path
import subprocess,shutil,resource,json,sys,itertools
r=Path(__file__).resolve().parent;work=r/'observer-src'
for file in ['Lisplikefns.hs','Rewritefns.hs','Checker.hs','Rulebasetext.hs']:shutil.copy(r/file,work/file)
p=work/'Lisplikefns.hs';p.write_text(p.read_text().replace('Token, Lisplist(..), LUT,','Token, Lisplist(..), LUT(..),'))
(work/'Kernel.hs').write_text((r/'Main.hs').read_text().replace('module Main(main) where','module Kernel where'))
(work/'Observer.hs').write_text('''module Main where
import Kernel
import Lisplikefns
import Rewritefns
import System.Environment
sex Nil="()"
sex (Atom s)=s
sex (Cons(a,b))="("++sex a++" . "++sex b++")"
lut Empty=[]
lut (Node(a,(k,rs),b))=lut a++[(k,length rs)]++lut b
main=do
 [arg]<-getArgs
 let i=read arg
 print(lut lemmas)
 putStrLn(sex(teststatement i))
 putStrLn(sex(rewrite(teststatement i)lemmas))
 print(testresult i)
''')
with(r/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',str(r/'observer'),'Observer.hs'],cwd=work,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(180,180))
for i in [1,2,60,600]:
 raw=subprocess.check_output([str(r/'observer'),str(i)],timeout=195,preexec_fn=bounded);(r/('observer-'+str(i)+'.txt')).write_bytes(raw);print('PASS complete original normal-form observer',i,len(raw),'bytes',flush=True)
