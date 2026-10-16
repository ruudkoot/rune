module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 putStr(concat[f_generate n|n<-[1..read arg]])
