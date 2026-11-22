-- Report 13: Complex has no Ord instance: (1 :+ 0) < (2 :+ 0) is refused.
module Main (main) where

import Complex

x :: Bool
x = (1 :+ 0) < (2 :+ 0 :: Complex Double)

main :: IO ()
main = return ()
