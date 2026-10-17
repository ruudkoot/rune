module Main where
import KernelPrime
import MyRandom
import IntLib
import System.Environment
emit label state number=do
 let (passed,after)=multiTest 100 state number
 putStrLn(label++" "++show number++" "++(if passed then "1"else"0")++" "++unwords(map show(take 4 after)))
 return after
walk _ state []=return ()
walk i state (n:ns)=do
 after<-emit(show i)state n
 walk(i+1)after ns
main=do
 [file]<-getArgs
 text<-readFile file
 putStrLn("raw "++unwords(map show(take 16(randomInts 111 47))))
 walk(0::Int)(randomInts 111 47)(map readInteger(lines text))
