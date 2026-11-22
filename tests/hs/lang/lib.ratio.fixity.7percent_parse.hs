-- Report 12.1: infixl 7 %: 1 % 2 * 3 is (1 % 2) * 3, not 1 % 6, and 6 % 2 + 1 is (6 % 2) + 1, not 2.
module Main (main) where

import Ratio

main :: IO ()
main = do
  print (1 % 2 * 3 :: Rational)
  print (6 % 2 + 1 :: Rational)
