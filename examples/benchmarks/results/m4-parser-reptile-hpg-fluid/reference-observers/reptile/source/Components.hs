module Components where
import qualified Layout as L
import qualified Mgrfuns as M
import qualified Geomfuns as G
import qualified Drawfuns as D
import qualified Rational as R
import NofibUtils(hash)
import Data.Char(ord)
main=do
 mapM_(\(name,s)->print(name,length s,hash s,map ord s))[
  ("dpgrid",L.dpgrid),("tpgrid",L.tpgrid),("tmgrid",L.tmgrid),("dmgrid",L.dmgrid),
  ("picgrid",L.picgrid),("setup",L.setup),("todesign",L.todesign),("totile",L.totile),
  ("tofiddle",L.tofiddle),("tohelp",L.tohelp),("invisibletext",L.invisibletext),
  ("line",M.line[1,-2,30,40]),("setevent",M.setevent 3 "abc\n"),
  ("fillrect",D.fillrect[1,2,3,4]),("tile",G.tile 10 20 2 2[[0,0,1,1]])]
 mapM_ print[R.radd(1,3)(2,7),R.rsub(1,3)(2,7),R.rmul(1,3)(2,7),R.rdiv(1,3)(2,7)]
