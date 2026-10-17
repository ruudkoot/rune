module Main where
import Pair
import System.Environment
main=do
 [arg]<-getArgs
 print(isos(read arg))
