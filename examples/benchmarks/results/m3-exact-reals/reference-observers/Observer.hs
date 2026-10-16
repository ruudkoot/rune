module Main where
import Kernel
import System.Environment
sine x=sin(x*pi)
main=do
 [arg]<-getArgs
 let n=read arg::Int
 let value=sum(map sine [1..fromIntegral n::CR])
 print(bits(digitsToBits digits)value)
 putStrLn(get_str digits value)
