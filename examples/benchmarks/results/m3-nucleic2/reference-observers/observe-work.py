from pathlib import Path
import subprocess,json,ast
p=Path(__file__).resolve().parent
source=r'''module Work where
import qualified Main as N
import Types
import Data.IORef
import System.IO.Unsafe(unsafePerformIO)
import Control.Exception(evaluate)
import GHC.Float(castFloatToWord32)
{-# NOINLINE counts #-}
counts=unsafePerformIO(newIORef(0,0,0,0,0,0::Int))
{-# NOINLINE predicate #-}
predicate v@(N.Var i _ _) partial=unsafePerformIO $ do
 pass<-evaluate(N.pseudoknot_constraint v partial)
 modifyIORef' counts $ \(a,b,c,d,e,f)->(a+1,b+if pass then 1 else 0,c+if i==18 then 1 else 0,d+if i==18&&pass then 1 else 0,e+if i==6 then 1 else 0,f+if i==6&&pass then 1 else 0)
 return pass
main=do
 let xs=N.search [] N.pseudoknot_domains predicate
 result<-evaluate(N.most_distant_atom xs)
 print(length xs,castFloatToWord32 result)
 readIORef counts >>= print
'''
records=[]
for mode in ['on-demand','shared']:
 w=p/mode;(w/'Work.hs').write_text(source)
 cmd=['ghc','-O2','-cpp','-rtsopts','-fforce-recomp']+(['-DUSE_HARTEL_LAZINESS']if mode=='shared'else[])+['-main-is','Work.main','Work.hs','Main.hs','-o','observe-work']
 with(w/'work-build.log').open('w')as out:r=subprocess.run(cmd,cwd=w,stdout=out,stderr=subprocess.STDOUT)
 assert r.returncode==0
 r=subprocess.run(['./observe-work','+RTS','-M1g','-RTS'],cwd=w,capture_output=True,timeout=120)
 (w/'work.reference').write_bytes(r.stdout);(w/'work.stderr').write_bytes(r.stderr)
 assert r.returncode==0
 values=[ast.literal_eval(l)for l in r.stdout.decode().splitlines()]
 records.append(dict(mode=mode,exit=r.returncode,result=values))
 print(records[-1],flush=True)
assert records[0]['result']==records[1]['result']
(p/'work-reference-exits.json').write_text(json.dumps(records,indent=2)+'\n')
