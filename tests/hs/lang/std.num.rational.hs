-- rows: std.num.table.ratio std.coerce.torational std.coerce.simplest lib.r.ratio.approx.zero
-- Report 6.4: Rational is Ratio Integer, with the Ratio library's %; truncate of a ratio; toRational 0.75 is 3 % 4;
-- 6.4.6: approxRational gives the simplest rational within the bound.
module Main (main) where

import Ratio

main :: IO ()
main = do
  print (3 % 4 + 1 % 4 == (1 :: Rational), numerator (6 % 8 :: Rational), denominator (6 % 8 :: Rational))
  print (truncate (7 % 2 :: Rational) :: Integer, toRational (0.75 :: Double) == 3 % 4)
  print (approxRational (0.5 :: Double) 1, approxRational (0.1 :: Double) 0.2)
