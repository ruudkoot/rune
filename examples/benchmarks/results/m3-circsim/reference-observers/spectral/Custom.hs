module Main where
import Kernel
import System.Environment
rows n c = [[if t `mod` 3==1 then F else T]++[if (t*5+i*3+t `div` 2) `mod` 7<3 then T else F|i<-[0..n-1]]|t<-[0..c-1]]
main=do
 [b,c]<-getArgs
 let n=read b; count=read c; input=rows n count
 print input
 print(circuit_simulate input(pad_circuit(regs n)))
 print[xor a b|a<-[F,T],b<-[F,T]]
