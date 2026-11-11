-- rows: R45
-- Report 6.4.6 (R45; ruling 49 makes the row a run): what truncate, round, ceiling, floor and toRational return for a
-- NaN or an infinity is not stated. rhc's choice, R45's seed made concrete: an error, every one of them (and so
-- realToFrac, which is fromRational . toRational, of a NaN); here round of a NaN, after a finite value.
module Main (main) where

nan :: Double
nan = 0 / 0

main :: IO ()
main = do
  print (round (2.5 :: Double) :: Integer, truncate (-1.5 :: Double) :: Int)
  print (round nan :: Integer)
