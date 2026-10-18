from pathlib import Path
import re,shutil,subprocess,resource
p=Path(__file__).resolve().parent;o=p/'observer-source';shutil.copytree(p/'source',o,dirs_exist_ok=True)
t=(o/'Main.hs').read_text().replace('module Main (main)','module Kernel')
t='{-# LANGUAGE DeriveDataTypeable #-}\n'+t.replace('    import Control.Monad','    import Data.Data (Data, Typeable);\n    import Control.Monad')
t=re.sub(r'(data\n\s+[^;]+)(;)',lambda m:m[1]+' deriving (Data,Typeable)'+m[2],t)
(o/'Kernel.hs').write_text(t)
observer=r'''{-# LANGUAGE ScopedTypeVariables #-}
module Main where
import Kernel
import Data.Data
import Data.Char (ord)
import System.Environment
quote s="\""++concatMap esc s++"\"" where
 esc '"'="\\\""
 esc '\\'="\\\\"
 esc '\n'="\\n"
 esc '\r'="\\r"
 esc '\t'="\\t"
 esc c=[c]
dump :: Data a=>a->String
dump x=case cast x of
 Just(n::Int)->show n
 Nothing->case cast x of
  Just(c::Char)->show(ord c)
  Nothing->case cast x of
   Just(s::String)->quote s
   Nothing->"["++quote(showConstr(toConstr x))++concatMap(","++)(gmapQ dump x)++"]"
main=do
 [mode,path]<-getArgs
 txt<-readFile path
 case mode of
  "program"->putStr(c_the_program 1)
  "tokens"->putStrLn(dump(f_tokenize txt))
  "parse"->putStrLn(dump(c_par_proglist(f_tokenize txt)))
'''
(o/'Observe.hs').write_text(observer)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-rtsopts','Observe.hs','-o','observe'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
r=subprocess.run([str(o/'observe'),'program','/dev/null'],capture_output=True,check=True,timeout=60,preexec_fn=cap);(p/'program.input').write_bytes(r.stdout)
cases=[('default',r.stdout.decode()),('identity','main x = x;\n'),('application','main x = f x (g 2);\n'),('types','TYPE tList a = [ N | C, a, tList a ];\nFTYPE id = #a -> #a;\nid x = x;\n'),('conditional','main x = IF x < 2 THEN 1 ELIF x == 2 THEN 2 ELSE 3 FI;\n'),('let-case','main x = LET a = 1; IN CASE x { <N> a; <C b bs> b; };\n'),('lexemes','main x = "a\\n";\n/* comment\nline */\n'),('bad','main x = ;\n'),('empty',''),('unterminated-comment','/* no end')]
for name,text in cases:
 (p/(name+'.input')).write_text(text)
 for mode in ['tokens','parse']:
  r=subprocess.run([str(o/'observe'),mode,str(p/(name+'.input'))],capture_output=True,timeout=120,preexec_fn=cap)
  (p/(name+'-'+mode+'.reference')).write_bytes(r.stdout);(p/(name+'-'+mode+'.stderr')).write_bytes(r.stderr)
  print(name,mode,r.returncode,len(r.stdout),flush=True)
  if name=='default':assert r.returncode==0
