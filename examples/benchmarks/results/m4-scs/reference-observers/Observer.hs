module Main where
import Kernel
import System.Environment
import qualified Parse
main=do
 [file,seed,dt,end,temp,rbc]<-getArgs
 scs file (read seed) (head (Parse.parse_exact dt)) (head (Parse.parse_exact end)) (head (Parse.parse_approx temp)) (head (Parse.parse_approx rbc))
