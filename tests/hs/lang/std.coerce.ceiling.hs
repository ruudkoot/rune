-- rows: std.coerce.floor std.coerce.truncate std.coerce.round std.coerce.round.even std.coerce.proper std.coerce.proper.sign std.coerce.proper.zero std.coerce.fromintegral std.coerce.realtofrac R45
-- Report 6.4.6: ceiling, floor, truncate and round, round to even at the half; properFraction keeps the sign, with the
-- erratum of June 2003; fromIntegral and realToFrac.
module Main (main) where

main :: IO ()
main = do
  print (map ceiling [2.5, -2.5, 3.0 :: Double] :: [Int], map floor [2.5, -2.5, 3.0 :: Double] :: [Int], map truncate [2.5, -2.5, 3.0 :: Double] :: [Int])
  print (round (2.7 :: Double) :: Int, map round [2.5, 3.5, -2.5 :: Double] :: [Int])
  print (properFraction (3.75 :: Double) :: (Int, Double), properFraction (-3.75 :: Double) :: (Int, Double), properFraction (0.5 :: Double) :: (Int, Double))
  print (fromIntegral (3 :: Int) :: Double, realToFrac (1.5 :: Float) :: Double)
