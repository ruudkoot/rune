-- Report 14.1, 14.4: Just d shows at most d digits after the point, rounded by roundTo, which takes a half up; and
-- showEFloat shows at least one digit after its point, as the code's max dec 1 says.
module Main (main) where

import Numeric

main :: IO ()
main = do
  print (showFFloat (Just 1) (0.25 :: Double) "", showFFloat (Just 0) (2.5 :: Double) "", showFFloat (Just 3) (0.0005 :: Double) "")
  print (showEFloat (Just 0) (1250 :: Double) "", showEFloat (Just 1) (0.125 :: Double) "", showGFloat (Just 1) (-0.25 :: Double) "")
