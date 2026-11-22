-- Report 13: Complex needs a RealFloat component: (1 :+ 2) :: Complex Int is refused.
module Main (main) where

import Complex

x :: Complex Int
x = 1 :+ 2

main :: IO ()
main = return ()
