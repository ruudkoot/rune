from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;o=p/'codegen-observer-source'
shutil.copytree(p/'source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','original','TestInput.hs'))
observer=r'''module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import LALR
import ProduceCode
import AbsSyn
import Target
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
 let AbsSyn hd _ _ tl=ast
     header=Just(maybe "" id hd++"\n")
 putStr(produceParser g at gt "" header tl TargetHaskell False False False)
'''
(o/'MainCodegen.hs').write_text(observer)
with(p/'codegen-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-cpp','-rtsopts','-fforce-recomp','MainCodegen.hs','-o','observe-codegen'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
data=p/'codegen-data';data.mkdir(exist_ok=True);records=[]
for row in json.loads((p/'lr0-cases.json').read_text()):
 name=row['name'];r=subprocess.run([str(o/'observe-codegen'),str(p/'grammar-data'/(name+'.input')),'+RTS','-M1g','-RTS'],capture_output=True,check=True,timeout=120)
 (data/(name+'.reference')).write_bytes(r.stdout)
 records.append(dict(name=name,bytes=len(r.stdout)))
 print(records[-1],flush=True)
(p/'codegen-cases.json').write_text(json.dumps(records,indent=2)+'\n')
