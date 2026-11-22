-- rows: std.float.digits std.float.range std.float.ieee std.double.ieee
-- Report 6.4.6: RealFloat at IEEE Float and Double: radix 2, 24 and 53 digits, ranges (-125,128) and (-1021,1024).
module Main (main) where

main :: IO ()
main = do
  print (floatRadix (1 :: Double), floatDigits (1 :: Float), floatDigits (1 :: Double), floatRange (1 :: Float), floatRange (1 :: Double))
