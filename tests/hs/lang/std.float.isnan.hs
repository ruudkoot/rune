-- rows: std.float.isinfinite std.float.isnegzero std.float.isieee
-- Report 6.4.6: isNaN (0/0), isInfinite (1/0) and isNegativeZero (-0.0) at IEEE Double, and isIEEE at Double and Float,
-- as IEEE 754 says.
module Main (main) where

main :: IO ()
main = print (isNaN (0 / 0 :: Double), isInfinite (1 / 0 :: Double), isNegativeZero (-0.0 :: Double), isIEEE (1 :: Double), isIEEE (1 :: Float))
