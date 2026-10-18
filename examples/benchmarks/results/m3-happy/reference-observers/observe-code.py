from pathlib import Path
import json,shutil,subprocess,re
p=Path(__file__).resolve().parent;o=p/'code-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
f=o/'Grammar.lhs';t=f.read_text();t,n=re.subn(r'(>\s+Name, isEmpty,)',r'\1\n> doCheckCode,',t,count=1);assert n==1;f.write_text(t)
helpers=(p/'lexer-observer-source/ObserveLexer.hs').read_text();a=helpers.index('js s=');b=helpers.index('ids=',a)
observer='''module Main where
import Grammar(doCheckCode)
import GenUtils(MaybeErr(..))
import Data.Char
import Numeric(showHex)
import Data.List(intercalate)
import Control.Exception
import System.Environment
'''+helpers[a:b]+r'''
result n s=case doCheckCode n s of
 Succeeded(code,used)->arr[js"ok",js code,arr(map show used)]
 Failed errors->arr[js"errors",arr(map js errors)]
main=do
 [n,path]<-getArgs
 s<-readFile path
 r<-try(evaluate(let x=result(read n)s in seq(length x)x))::IO(Either SomeException String)
 putStrLn(case r of Right x->x;Left e->arr[js"exception",js(takeWhile(/='\n')(displayException e))])
'''
(o/'ObserveCode.hs').write_text(observer)
ast=json.loads((p/'parser-data/default.reference').read_text())
cases=[]
for nt,rules,_ in ast[3]:
 for names,code,line,prec in rules:cases.append(dict(arity=len(names),code=code,origin='TestInput.y:'+nt+':'+str(line)))
for arity,code in [(0,'plain'),(1,'$1'),(3,'$1+$3+$>'),(1,'\\$1 + $1'),(1,'"\\x41" ++ \'\\x42\' ++ $1'),(1,"f' $1 g'"),(0,'$> then $2'),(1,'$2+$3'),(3,'$0x2+$0O3'),(1,'"$1" \'$\' $1'),(1,'"\\SO\\&H" $1'),(1,'$1.abc'),(1,'$1e2')]:
 cases.append(dict(arity=arity,code=code,origin='synthetic'))
data=p/'code-data';data.mkdir(exist_ok=True)
with(p/'code-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','ObserveCode.hs','-o','observe-code'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for i,row in enumerate(cases):
 row['name']=str(i);(data/(str(i)+'.input')).write_text(row['code'])
 r=subprocess.run([str(o/'observe-code'),str(row['arity']),str(data/(str(i)+'.input'))],capture_output=True,check=True,timeout=30)
 json.loads(r.stdout);(data/(str(i)+'.reference')).write_bytes(r.stdout)
(p/'code-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
print(len(cases),'original action-normalization records, including every actual default rule')
