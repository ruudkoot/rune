from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent
cases=['',' ','x','(x','\\x.x','\\x.x x','let id = \\x.x in id id','let id = \\x.x in unit id','\\x. let f = x in f f','letx=\\y.y in x','let id = \\x.x in let id = id in id','\\unit. unit','\\x x. x','let f = \\x.x in let g = f in g g','\\f. let x = f in x','append (unit (\\x.x)) (unit (\\y.y))','fix (\\x.x)','fix unit','let in = x in in','x ?','unit unit','\\a b. let x = a b in x','\\x. let y = \\z.x in y','(\\x. x) (let id = \\x.x in id id)']
rows=[]
for i,case in enumerate(cases):
 data=(case+'\n').encode();output=subprocess.check_output([str(p/'observer')],input=data,timeout=10);(p/(f'edge-{i}.input')).write_bytes(data);(p/(f'edge-{i}.text')).write_bytes(output)
 h=0
 for byte in output:h=(31*h+byte)&((1<<64)-1)
 rows.append(dict(case=i,input=case,bytes=len(output),unsigned_hash=str(h),response=output.decode().split('\n? ',1)[1]));print(i,case,repr(rows[-1]['response']),flush=True)
(p/'edge-metadata.json').write_text(json.dumps(rows,indent=2)+'\n')
source='''module Main where
import Kernel ()
import Parse
import Type
import Environment
import InferMonad
import Substitution
main=do
 print (useP False (lexactlyP (starP alphaP `thenP` (\\_ -> litP 'a' `eachP` (const True)))) "a")
 let s1=extendSub emptySub "x" (TVar "y")
 let s2=extendSub s1 "y" (TCon "List" [TVar "z"])
 let s3=extendSub s2 "x" (TVar "w")
 print [(x,show(lookupSub s3 x)) | x<-domSub s3]
 let env=extendLocal (makeEnv [("x",All [] (TVar "a"))]) "x" (TVar "b")
 print (freeTVarEnv env)
'''
(p/'BoundaryObserver.hs').write_text(source)
with(p/'boundary-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','boundary-observer','BoundaryObserver.hs'],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(p/'boundary-observer')],timeout=10);(p/'boundaries.output').write_bytes(raw);print(raw.decode(),flush=True)
