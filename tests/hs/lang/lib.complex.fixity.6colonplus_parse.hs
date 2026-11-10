-- Report 13.1: infix 6 :+: 1 * 2 :+ 3 * 4 is (1 * 2) :+ (3 * 4), below *; and above function application's level, so
-- negate 1 :+ 2 is (negate 1) :+ 2.
module Main (main) where

import Complex

main :: IO ()
main = do
  print (1 * 2 :+ 3 * 4 :: Complex Double)
  print (realPart (negate 1 :+ 2 :: Complex Double))
