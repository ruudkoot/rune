module Main where
import BaseDefs
import MyUtils
import Data.List(intercalate)
domains=[Two,Lift1[],Lift1[Two],Lift2[],Lift2[Two],Func[]Two,Func[Two]Two,
 Func[Two,Two]Two,Func[Lift1[Two]](Lift2[Two]),Lift1[Func[Two]Two]]
frontier=Min1Max0 1[MkFrel[One]][MkFrel[Zero]]
routes=[Zero,One,Stop1,Up1[],Up1[Zero],Stop2,Up2,UpUp2[],UpUp2[One],
 Rep(RepTwo frontier),Rep(Rep1 frontier[]),Rep(Rep2 frontier frontier[])]
letter LT='L'
letter EQ='E'
letter GT='G'
main=do
 putStrLn(map(\(x,y)->letter(compare x y))[(x,y)|x<-domains,y<-domains])
 putStrLn(map(\(x,y)->letter(compare x y))[(x,y)|x<-routes,y<-routes])
 print(myCartesianProduct([[1,2],[10,20],[100,200]]::[[Int]]))
 print(myListVariants([1,2]::[Int])[[10,11],[20,21]])
 print((MkExInt(maxBound::Int)[]+MkExInt 1[])::ExceptionInt Domain)
 print((MkExInt(9223372036854775807::Int)[]*MkExInt 2[])::ExceptionInt Domain)
