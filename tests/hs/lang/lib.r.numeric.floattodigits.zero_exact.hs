-- Report 14.4: floatToDigits _ 0 = ([], 0), the code's first equation, and the three formats of zero from it.
module Main (main) where

import Numeric

main :: IO ()
main = do
  print (floatToDigits 10 (0 :: Double), floatToDigits 2 (0 :: Float), floatToDigits 16 (-0.0 :: Double))
  print (showEFloat Nothing (0 :: Double) "", showFFloat Nothing (0 :: Double) "", showGFloat Nothing (0 :: Double) "", showEFloat (Just 2) (0 :: Double) "")
