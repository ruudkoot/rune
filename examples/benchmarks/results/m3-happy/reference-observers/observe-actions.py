from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'actions-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
observer=r'''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import LALR
import Data.Array
import Data.List(intercalate)
import System.Environment
arr xs="["++intercalate","xs++"]"
assoc x=case x of LeftAssoc->"0";RightAssoc->"1";None->"2"
prio No="[0]"
prio(Prio a n)=arr["1",assoc a,show n]
action a=case a of
 LR'Shift s p->arr["0",show s,prio p]
 LR'Reduce r p->arr["1",show r,prio p]
 LR'Accept->"[2]"
 LR'Fail->"[3]"
 LR'MustFail->"[4]"
 LR'Multiple xs x->arr["5",arr(map action xs),action x]
goto NoGoto="[0]"
goto(Goto n)=arr["1",show n]
pair(a,b)=arr[show a,show b]
main=do
 [input]<-getArgs
 text<-readFile input
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     first=mkFirst g
     states=genLR0items g(precalcClosure0 g)
     (s,p)=propLookaheads g states first
     las=calcLookaheads(length states)s p
     items=mergeLookaheadInfo las states
     gt=genGotoTable g states
     at=genActionTable g first items
     (counts,(sr,rr))=countConflicts at
 putStrLn(arr(map(\(i,row)->arr[show i,arr(map(\(n,x)->arr[show n,goto x])(assocs row))])(assocs gt)))
 putStrLn(arr(map(\(i,row)->arr[show i,arr(map(\(n,x)->arr[show n,action x])(assocs row))])(assocs at)))
 putStrLn(arr(map(\(i,x)->arr[show i,pair x])(assocs counts)))
 putStrLn(pair(sr,rr))
'''
(o/'MainActions.hs').write_text(observer)
with(p/'actions-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-rtsopts','-fforce-recomp','MainActions.hs','-o','observe-actions'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
data=p/'actions-data';data.mkdir(exist_ok=True);records=[]
for row in json.loads((p/'lr0-cases.json').read_text()):
 name=row['name'];r=subprocess.run([str(o/'observe-actions'),str(p/'grammar-data'/(name+'.input')),'+RTS','-M1g','-RTS'],capture_output=True,check=True,timeout=120)
 lines=r.stdout.splitlines();assert len(lines)==4
 for mode,line in zip(['goto','action','per-state','counts'],lines):
  json.loads(line);(data/(name+'-'+mode+'.reference')).write_bytes(line+b'\n')
 counts=json.loads(lines[3]);records.append(dict(name=name,shift_reduce=counts[0],reduce_reduce=counts[1],action_bytes=len(lines[1]),goto_bytes=len(lines[0])))
 print(records[-1],flush=True)
(p/'actions-cases.json').write_text(json.dumps(records,indent=2)+'\n')
