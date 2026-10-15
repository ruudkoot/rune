module Main where
import qualified Kernel as K
import System.Environment
main=getArgs >>= \[year] -> putStr(K.cal(read year::Int))
