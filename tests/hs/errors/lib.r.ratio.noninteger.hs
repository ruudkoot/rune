-- Report 12: Ratio needs an Integral component: 1 % 2 :: Ratio Float is refused.
module Main (main) where

import Ratio

x :: Ratio Float
x = 1 % 2

main :: IO ()
main = return ()
