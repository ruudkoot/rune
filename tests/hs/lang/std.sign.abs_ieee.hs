-- rows: std.sign.signum R45 R78
-- Report 6.4.4, readings.md R78 (implementation-defined): abs and signum at IEEE's -0.0 and NaN, and abs x * signum x == x.
module Main (main) where

xs :: [Double]
xs = [-2.5, -0.0, 0, 3]

main :: IO ()
main = do
  print (abs (-0.0 :: Double) == 0, isNegativeZero (abs (-0.0 :: Double)), isNegativeZero (signum (-0.0 :: Double)))
  print (isNaN (abs (0 / 0 :: Double)), isNaN (signum (0 / 0 :: Double)))
  print [abs x * signum x == x && isNegativeZero (abs x * signum x) == isNegativeZero x | x <- xs]
