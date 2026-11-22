-- Report 6.4: Complex is the Complex library's: sqrt ((-4) :+ 0) is 0.0 :+ 2.0 by its definition.
module Main (main) where

import Complex

main :: IO ()
main = print (sqrt ((-4) :+ 0) :: Complex Double)
