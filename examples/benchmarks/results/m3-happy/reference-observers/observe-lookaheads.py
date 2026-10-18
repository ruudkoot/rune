from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'lookahead-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
observer=r'''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import LALR
import qualified Data.Set as S
import Data.Array
import Data.List(intercalate)
import System.Environment
arr xs="["++intercalate","xs++"]"
pair(a,b)=arr[show a,show b]
names s=arr(map show(S.toAscList s))
spont(i,item,s)=arr[show i,pair item,names s]
prop(item,i,target)=arr[pair item,show i,pair target]
la(item,s)=arr[pair item,names s]
lr1(rule,dot,s)=arr[show rule,show dot,names s]
main=do
 [input]<-getArgs
 text<-readFile input
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     first=mkFirst g
     states=genLR0items g(precalcClosure0 g)
     (s,p)=propLookaheads g states first
     final=calcLookaheads(length states)s p
     merged=mergeLookaheadInfo final states
 putStrLn(arr(map spont s))
 putStrLn(arr(map(\(i,edges)->arr[show i,arr(map prop edges)])(assocs p)))
 putStrLn(arr(map(\(i,items)->arr[show i,arr(map la items)])(assocs final)))
 putStrLn(arr(map(\(items,gotos)->arr[arr(map lr1 items),arr(map pair gotos)])merged))
'''
(o/'MainLookahead.hs').write_text(observer)
with(p/'lookahead-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-rtsopts','-fforce-recomp','MainLookahead.hs','-o','observe-lookahead'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
data=p/'lookahead-data';data.mkdir(exist_ok=True);records=[]
for row in json.loads((p/'lr0-cases.json').read_text()):
 name=row['name'];r=subprocess.run([str(o/'observe-lookahead'),str(p/'grammar-data'/(name+'.input')),'+RTS','-M1g','-RTS'],capture_output=True,check=True,timeout=120)
 lines=r.stdout.splitlines();assert len(lines)==4
 for mode,line in zip(['spontaneous','propagated','final','merged'],lines):
  json.loads(line);(data/(name+'-'+mode+'.reference')).write_bytes(line+b'\n')
 arrays=list(map(json.loads,lines));records.append(dict(name=name,spontaneous=len(arrays[0]),propagated=sum(len(r[1])for r in arrays[1]),array_rows=len(arrays[2]),lookahead_items=sum(len(r[1])for r in arrays[2])))
 print(records[-1],flush=True)
(p/'lookahead-cases.json').write_text(json.dumps(records,indent=2)+'\n')
