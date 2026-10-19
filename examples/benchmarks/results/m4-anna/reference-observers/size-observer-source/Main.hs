module Main where
import BaseDefs
import SmallerLattice
import FrontierMisc2
import MyUtils
import Utils
import Data.List(intercalate)
showPair(f,c)="("++show f++","++show c++")"
domains=[Two,Lift1[Two],Lift2[Two],Lift1[Two,Two],Lift2[Two,Two],Func[Two]Two,Func[Two,Two]Two,Func[Two](Lift1[Two]),Func[Two](Lift2[Two]),Func[Func[Two]Two]Two]
table=[(Func[Two,Two]Two,6),(Func[Lift1[Two]](Lift1[Two]),10)]
groups=[[Two],[Lift1[Two]],[Lift2[Two]],[Two,Two],[Lift1[Two],Two],[Lift2[Two],Lift1[Two]]]
main=do
 mapM_(print.slNorm)domains
 mapM_(print.slReduce)domains
 mapM_(print.slCard table)domains
 mapM_(\ds->print(slMakeOneSequence table 20 ds))groups
 mapM_(\limits->print(slMakeSequence table 20 groups(fst limits)(snd limits)))[(0,1000000),(3,8),(10,1)]
 print(take 24(utRandomInts 1 2))
 print(slDijkstra[(0,1,1),(0,2,1),(1,3,1),(2,3,1)](0::Int)3)
