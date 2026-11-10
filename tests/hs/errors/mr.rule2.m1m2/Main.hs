-- Report 4.5.5, Rule 2: a module's variables' types are its own: M1 defaults len1 to Int, so M2 cannot use it
-- at Rational (R20, D32).
module Main (main) where

import Ratio
import M1

len2 :: Rational
len2 = 2 * len1

main :: IO ()
main = print len2
