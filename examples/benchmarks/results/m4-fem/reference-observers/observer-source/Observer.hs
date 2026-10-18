module Main where
import qualified Database as D
import qualified Data.Array as A
import qualified DB_interface as DB
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
floats name values=emit name(map(\x->showHex(castFloatToWord32 x)"")values)
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
 ints"degrees"(concatMap(G.getndgr db)[1..DB.nnode db])
 ints"degree-count"[G.ndgrs db]
 ints"diagonal"(vec(P.diagadr db))
 floats"stiffness"(band a)
 floats"decomposition"(band l)
 floats"load"(vec b)
 floats"forward"(vec forward)
 floats"solution"(vec back)
 floats"displacement"(vec u)
 floats"forces"(vec f)
