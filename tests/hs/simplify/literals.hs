-- fromInteger and fromRational of literals folded where the instance is
-- known (Augustsson 1993, section 4.3), at -O2, and not otherwise: what a
-- polymorphic function's literals give at each type.
module Main where

half :: Fractional a => a -> a
half x = x * 0.5

scale :: Fractional a => a -> a
scale x = x * 1.25e-3 + 2.5e2

big :: Num a => a
big = 9007199254740993

small :: Num a => a
small = 16777217

tenth :: Fractional a => a
tenth = 0.1

main :: IO ()
main = do
  print (half (3 :: Double), half (3 :: Float))
  print (scale (8 :: Double), scale (8 :: Float))
  print (big :: Double, big :: Integer, big :: Int)
  print (small :: Float, small :: Double)
  print (tenth :: Double, tenth :: Float, tenth * 3 :: Double)
  print (toRational (tenth :: Double) == toRational (0.1 :: Double))
  print (fromIntegral (3 :: Int) + (0.5 :: Double), realToFrac (1.5 :: Float) :: Double)
  print (1e22 :: Double, 2.5e-300 :: Double, 123456789.123456789 :: Double)
