from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'first-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
observer=r'''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import qualified Data.Set as S
import Data.Array
import System.Environment
main=do
 [input,queries]<-getArgs
 text<-readFile input
 qs<-readFile queries
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     f=mkFirst g
 mapM_(\line->print(S.toAscList(f(read line::[Int]))))(lines qs)
'''
(o/'MainFirst.hs').write_text(observer)
with(p/'first-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-fforce-recomp','MainFirst.hs','-o','observe-first'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
data=p/'first-data';data.mkdir(exist_ok=True);records=[]
for name in json.loads((p/'grammar-cases.json').read_text()):
 original=json.loads((p/'grammar-data'/(name+'.reference')).read_text())
 if original[0]!='grammar':continue
 g=original[1];names=[row[0]for row in g[7]]
 queries=[[]]+[[i]for i in [0]+names]
 for prod in g[0]:
  rhs=prod[1];queries +=[rhs[i:]for i in range(len(rhs)+1)]
 # Keep duplicates as repeated forcing/sharing controls.
 (data/(name+'.queries')).write_text(''.join(json.dumps(q)+'\n'for q in queries))
 r=subprocess.run([str(o/'observe-first'),str(p/'grammar-data'/(name+'.input')),str(data/(name+'.queries'))],capture_output=True,check=True,timeout=120)
 (data/(name+'.reference')).write_bytes(r.stdout)
 for line in r.stdout.splitlines():json.loads(line)
 assert len(r.stdout.splitlines())==len(queries)
 records.append(dict(name=name,queries=queries));print(name,len(queries),flush=True)
(p/'first-cases.json').write_text(json.dumps(records,indent=2)+'\n')
