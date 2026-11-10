-- rows: exp.lit.int.value
-- Report 3.2: n and d are chosen so that n/d is the literal exactly; an integer literal is an Integer of any size.
module Main (main) where

import Ratio

main :: IO ()
main = do
  print ((0.1 :: Rational) == 1 % 10)
  print ((0.1234567890123456789 :: Rational) == 1234567890123456789 % 10000000000000000000)
  print (123456789012345678901234567890 :: Integer)
