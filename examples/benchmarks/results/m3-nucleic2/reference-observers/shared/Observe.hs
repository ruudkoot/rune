module Observe where
import qualified Main as N
import Types
import GHC.Float(castFloatToWord32)
import Data.List(intercalate)
point(Pt x y z)=map castFloatToWord32[x,y,z]
atoms v@(N.Var i t n)=(i,map(point . N.absolute_pos v)(N.list_of_atoms n))
solution s=map atoms s
main=do
 let xs=N.pseudoknot "1"
 print(length xs)
 print(N.most_distant_atom xs,castFloatToWord32(N.most_distant_atom xs))
 mapM_(print . solution)xs
