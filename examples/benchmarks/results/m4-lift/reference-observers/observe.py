from pathlib import Path
import subprocess,shutil,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source'
shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('original','*.hi','*.o'),dirs_exist_ok=True)
(d/'Observer.hs').write_text('''module Main where
import LambdaLift
import Print
import Test
import Utilities
import System.Environment
import Data.List(intercalate)
sml(EConst(CNum n))="cn ("++show n++")"
sml(EConst(CBool b))="cb "++(if b then"true"else"false")
sml(EConst(CFun n))="cf "++show n
sml(EVar n)="variable "++show n
sml(EAp a b)="app ("++sml a++") ("++sml b++")"
sml(ELam args body)="lam ["++intercalate ","(map(\\n->"named "++show n)args)++"] ("++sml body++")"
sml(ELet rec defs body)="lett "++(if rec then"true"else"false")++" ["++intercalate ","(map(\\(n,r)->"(named "++show n++","++sml r++")")defs)++"] ("++sml body++")"
main=do
 args<-getArgs
 case args of
  ["input-sml"]->putStrLn("fun program()= "^sml program)
  ["input"]->putStr(pprintExpr program)
  ["plain"]->putStr(pprintSCs(lambdaLift program))
  ["full"]->putStr(pprintSCs(fullyLazyLift program))
  ["report"]->putStr("\\nInput expression "++pprintExpr program++"\\nResult\\n"++pprintSCs(lambdaLift program)++"\\nFully lazy \\n"++pprintSCs(fullyLazyLift program)++"\\n")
  _->error"expected input-sml|input|plain|full|report"
'''.replace('"fun program()= "^sml program','"fun program()= "++sml program'))
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for label in ['input-sml','input','plain','full','report']:
 r=subprocess.run([str(d/'observer'),label],capture_output=True,check=True,timeout=120,preexec_fn=cap)
 (p/(label+'.reference')).write_bytes(r.stdout);(p/(label+'.stderr')).write_bytes(r.stderr)
 print(label,len(r.stdout),flush=True)
# A source-derived constructor function is data-only adaptation, retaining the
# actual fixed Test.program AST with strings converted to explicit name cells.
(p/'program.sml').write_text((p/'input-sml.reference').read_text())
