-- Report 12: Ratio is abstract: its constructor :% is not exported.
module Main (main) where

import Ratio

x :: Rational
x = 1 :% 2

main :: IO ()
main = return ()
