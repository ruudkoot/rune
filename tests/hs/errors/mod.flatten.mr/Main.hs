-- Report 5, 4.5.5: the exception to flattening: Rule 2 holds module by module, so the M1 and M2 example is refused
-- though its flattened form is accepted (R20, D32).
module Main (main) where

import Ratio
import M1

len2 :: Rational
len2 = 2 * len1

main :: IO ()
main = print len2
