-- rows: R45
-- Report 6.4.3 (R45; ruling 49 makes the row a run): "0**y is undefined", which does not say bottom or unspecified.
-- rhc's choice, R45's seed: IEEE's pow, where Rune's real is, so 0 ** y is 0 for a positive y, 1 for 0 and an
-- infinity for a negative y, at Double and Float.
module Main (main) where

main :: IO ()
main = do
  print (0 ** 2 :: Double, 0 ** 0 :: Double, 0 ** (-1) :: Double)
  print (0 ** 0.5 :: Float, 0 ** 0 :: Float, 0 ** (-2) :: Float)
