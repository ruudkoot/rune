-- rows: lib.numeric.floattodigits R157
-- Report 14.4: at a mantissa that is a power of the radix, with e >= 0, the code takes mDn = b (readings.md R157, the lead's
-- ruling: the printed code stands), so its digits of 2^70 read back to the number but are not the shortest at
-- Float, nor the closest at Double; and show, by showFloat, prints them. The expected output is the code's twin's,
-- and its last line the code's show, written from it.
module Main (main) where

import Numeric

main :: IO ()
main = do
  print (floatToDigits 10 (2 ^ 70 :: Double), floatToDigits 10 (2 ^ 70 :: Float))
  putStrLn (showFloat (2 ^ 70 :: Double) "" ++ " " ++ showFloat (2 ^ 70 :: Float) "")
  print (floatToDigits 10 (2 ^ 60 :: Double), floatToDigits 10 (2 ^ 100 :: Float), floatToDigits 2 (2 ^ 70 :: Double))
  print (read (showFloat (2 ^ 70 :: Double) "") == (2 ^ 70 :: Double), read (showFloat (2 ^ 70 :: Float) "") == (2 ^ 70 :: Float))
  print (2 ^ 70 :: Double, 2 ^ 70 :: Float)
