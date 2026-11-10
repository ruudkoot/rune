-- rows: mr.rule2.m1.sig
-- Report 4.5.5, Rule 2: in that example len1 is Int, which M2 may use at Int; and a signature on len1 in M1
-- makes the Rational use legal (R20, D32).
module Main (main) where

import Ratio
import M1
import M3

len2 :: Int
len2 = 2 * len1

len4 :: Rational
len4 = 2 * len3

main :: IO ()
main = print (len2, len4)
