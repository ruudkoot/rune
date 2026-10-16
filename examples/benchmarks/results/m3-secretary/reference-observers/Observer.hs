module Main where
import Kernel
import System.Random
import Data.List
import System.Environment
main=do
 [arg]<-getArgs
 let n=read arg
 print [simN n k|k<-[35..39]]
