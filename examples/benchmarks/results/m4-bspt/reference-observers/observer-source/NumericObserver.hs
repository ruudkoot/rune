module Main where
import Rationals
emit name (p:%%q)=putStrLn(unwords[name,show p,show q])
main=do
 let values=[(1:%%2,2:%%3),(1:%%1,(-4):%%7),(3:%%5,2:%%1),(0:%%1,7:%%9)]
 mapM_(\(i,(a,b))->do emit("add"++show i)(a+b);emit("mul"++show i)(a*b);emit("sub"++show i)(a-b);emit("div"++show i)(a/b))(zip[0..]values)
 emit "overflow-add" ((maxBound:%%1)+1)
 emit "overflow-mul" (((4611686018427387904::Int):%%1)*4)
 mapM_(\(name,r)->putStrLn(name++" "++show(rndNR r))) [("round-pos",3:%%2),("round-neg",(-3):%%2),("round-third",1:%%3)]
 let a=1:%%2;b=2:%%4
 putStrLn(unwords["noncanonical",show(a==b),show(a<=b),show(a<b),show(a>b)])
