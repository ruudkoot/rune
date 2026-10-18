from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source'
shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('original','*.o','*.hi'),dirs_exist_ok=True)
f=d/'VBlldecomp.hs';s=f.read_text().replace("vblldecomp, vbllsolution, vbllsolution'","vblldecomp, vbllsolution, vbllsolution', forwarding, backwarding");f.write_text(s)
(d/'Observer.hs').write_text('''module Main where
import qualified Database as D
import qualified Data.Array as A
import qualified Degrees as G
import qualified Pre_assemble as P
import qualified Assemble_stiffness as K
import qualified Assemble_loadvec as B
import qualified Displacement as U
import qualified Elemforce as F
import qualified VBlldecomp as C
import qualified VBmatrix as M
import qualified Vector as V
import qualified PrintSource as PS
import qualified Printuvwforce as PU
import GHC.Float(castFloatToWord32)
import Numeric(showHex)
emit name values=putStrLn(name++" "++unwords values)
ints name values=emit name(map show values)
floats name values=emit name(map(\\x->showHex(castFloatToWord32 x)"")values)
vec v=map(V.vecsub v)[1..V.boundvec v]
band m=[M.vbmatsub m(i,j)|i<-[1..M.boundvbmat m],j<-[M.fstclvbmat m i..i]]
main=do
 s<-getContents
 let db=(D.idatabase s,D.rdatabase s)
     a=K.kdd db
     l=C.vblldecomp a
     b=B.loadvec db
     (forward,_)=C.forwarding(b,l)
     (back,_)=C.backwarding(forward,l)
     u=U.uvw db
     f=F.forces db u
 ints"idatabase"(A.elems(fst db))
 floats"rdatabase"(A.elems(snd db))
 ints"degrees"(concatMap(G.getndgr db)[1..((length(A.elems(fst db))-4)div 3)])
 ints"degree-count"[G.ndgrs db]
 ints"diagonal"(vec(P.diagadr db))
 floats"stiffness"(band a)
 floats"decomposition"(band l)
 floats"load"(vec b)
 floats"forward"(vec forward)
 floats"solution"(vec back)
 floats"displacement"(vec u)
 floats"forces"(vec f)
''')
# Use the actual node count, not a formula involving unrelated db storage.
f=d/'Observer.hs';s=f.read_text().replace('import qualified Degrees as G','import qualified DB_interface as DB\nimport qualified Degrees as G').replace('((length(A.elems(fst db))-4)div 3)','DB.nnode db');f.write_text(s)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for file in ['fem.stdin','data.0','data.1','data.2','data.3']:
 result=subprocess.run([str(d/'observer')],input=(d/file).read_bytes(),capture_output=True,timeout=120,preexec_fn=cap)
 (p/(file+'.observations')).write_bytes(result.stdout);(p/(file+'.observer-stderr')).write_bytes(result.stderr)
 record=dict(input=file,exit=result.returncode,bytes=len(result.stdout));records.append(record);print(record,flush=True)
(p/'observer-results.json').write_text(json.dumps(records,indent=2)+'\n')
