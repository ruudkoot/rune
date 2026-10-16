module Main where
import System.Random
cases :: [(Integer,Integer)]
cases=[(-10,10),(100,1),(0,0),(10^40,10^40+50),(-(10^50),10^50)]
main=mapM_(\(lo,hi)->let(value,g)=randomR(lo,hi)(mkStdGen 42) in print(lo,hi,value,show g))cases
