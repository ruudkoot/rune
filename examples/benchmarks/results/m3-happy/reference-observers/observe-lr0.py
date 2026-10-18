from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'lr0-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
observer=r'''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import LALR
import qualified Data.Set as S
import Data.List(intercalate)
import System.Environment
arr xs="["++intercalate","xs++"]"
pair(a,b)=arr[show a,show b]
main=do
 [input]<-getArgs
 text<-readFile input
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     closure=precalcClosure0 g
     states=genLR0items g closure
 putStrLn(arr(map(\n->arr[show n,arr(map pair(closure n))])(non_terminals g)))
 putStrLn(arr(map(\(set,gotos)->arr[arr(map pair(S.toAscList set)),arr(map pair gotos)])states))
'''
(o/'MainLR0.hs').write_text(observer)
with(p/'lr0-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-rtsopts','-fforce-recomp','MainLR0.hs','-o','observe-lr0'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
data=p/'lr0-data';data.mkdir(exist_ok=True);records=[]
for row in json.loads((p/'first-cases.json').read_text()):
 name=row['name']
 r=subprocess.run([str(o/'observe-lr0'),str(p/'grammar-data'/(name+'.input')),'+RTS','-M1g','-RTS'],capture_output=True,check=True,timeout=120)
 lines=r.stdout.splitlines();assert len(lines)==2
 closures,states=map(json.loads,lines)
 (data/(name+'-closures.reference')).write_bytes(lines[0]+b'\n');(data/(name+'-states.reference')).write_bytes(lines[1]+b'\n')
 records.append(dict(name=name,nonterminals=len(closures),states=len(states),gotos=sum(len(s[1])for s in states),items=sum(len(s[0])for s in states)))
 print(records[-1],flush=True)
(p/'lr0-cases.json').write_text(json.dumps(records,indent=2)+'\n')
