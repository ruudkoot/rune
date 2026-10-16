module Main where
import Kernel
import System.Environment
main=do
 [b,c]<-getArgs
 let values=run(read b)(read c)
 putStrLn("LENGTH "++show(length(show values)))
 print values
