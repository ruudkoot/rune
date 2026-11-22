-- Report 6.4.5, 8: atan2 of the signed zeros as the default's code gives them: atan2 0 0 is 0, atan2 0 (-0) is pi,
-- atan2 (-0) 0 is -0 and atan2 (-0) (-0) is -pi, at IEEE Double.
module Main (main) where

main :: IO ()
main = print (atan2 0 0 == (0 :: Double) && not (isNegativeZero (atan2 0 (0 :: Double))), atan2 0 (-0.0) == (pi :: Double), isNegativeZero (atan2 (-0.0) (0 :: Double)), atan2 (-0.0) (-0.0) == (- pi :: Double))
