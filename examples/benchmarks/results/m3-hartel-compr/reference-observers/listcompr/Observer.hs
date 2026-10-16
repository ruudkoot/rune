module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 putStr(f_main(read arg))
