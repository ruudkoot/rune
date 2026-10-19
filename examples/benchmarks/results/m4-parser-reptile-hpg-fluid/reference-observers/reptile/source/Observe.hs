module Observe where
import Mgrfuns
import Progfuns
import Auxprogfuns
import Layout
import Tilefuns
import NofibUtils(hash)
import Data.Char(ord)
import System.Environment(getArgs)
main=do
 [path,prefix]<-getArgs
 input<-readFile path
 let output=setmode 7++shapewindow[0,0,1150,900]++setup++
       potatotile([],1,initalist)(lines input)++
       shapewindow[0,0,500,500]++font 8++textreset++clear++func 15
 writeFile(prefix++".protocol")output
 writeFile(prefix++".codes")(show(map ord output)++"\n")
 writeFile(prefix++".hash")(show(hash output)++"\n")
 print(length output,hash output)
