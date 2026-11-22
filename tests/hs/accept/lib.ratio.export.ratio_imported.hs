-- rows: lib.ratio.export.rational lib.ratio.export.percent lib.ratio.export.numerator lib.ratio.export.denominator lib.ratio.export.approxrational
-- Report 12.1: module Ratio exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Ratio (Ratio, Rational, (%), numerator, denominator, approxRational)

t0 :: Ratio Int -> ()
t0 _ = ()

t1 :: Rational -> ()
t1 _ = ()

v2 _ = (%)

v3 _ = numerator

v4 _ = denominator

v5 _ = approxRational

main :: IO ()
main = return ()
