module Main where
import RichKernel
main=mapM_ report[A,B,C,D,X,Y,Z,U,W]
report ident=do
 let(term,_,_,_)=termDefs(Var ident)
 print(show ident,tautp term)
