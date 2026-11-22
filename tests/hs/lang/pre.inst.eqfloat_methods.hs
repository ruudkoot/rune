-- rows: pre.inst.ordfloat pre.inst.numfloat pre.inst.realfloat pre.inst.fractionalfloat pre.inst.floatingfloat pre.inst.realfracfloat pre.inst.realfloatfloat pre.inst.enumfloat
-- Report 8: the instances of Float: Eq, Ord, Num, Real, Fractional, Floating, RealFrac, RealFloat and Enum, each method on
-- sample values that a binary fraction holds exactly, the transcendental ones to a tolerance.
module Main (main) where

near :: Float -> Float -> Bool
near a b = abs (a - b) < 1.0e-4

main :: IO ()
main = do
  print (1.5 == (1.5 :: Float), 1.5 /= (1.5 :: Float), compare 1.5 (2.5 :: Float), max 1.5 (2.5 :: Float), min 1.5 (2.5 :: Float))
  print (1.5 + 2.25 :: Float, 1.5 - 2 :: Float, 1.5 * 2 :: Float, negate 1.5 :: Float, abs (-2.5) :: Float)
  print (signum (-2.5) :: Float, fromInteger 7 :: Float, toRational (0.75 :: Float) == 3 / 4, 7 / 2 :: Float, recip 4 :: Float)
  print (sqrt 4 :: Float, exp 0 :: Float, log 1 :: Float, sin 0 :: Float, cos 0 :: Float)
  print (near pi 3.14159, near (2 ** 3) 8, near (logBase 2 8) 3, near (tan 0) 0, near (atan 1 * 4) pi)
  print (near (asin 1) (pi / 2), near (acos 1) 0, near (sinh 0) 0, near (cosh 0) 1, near (tanh 0) 0)
  print (near (asinh 0) 0, near (acosh 1) 0, near (atanh 0) 0, fromRational (3 / 4) :: Float)
  print (properFraction (3.75 :: Float) :: (Int, Float), truncate (-2.5 :: Float) :: Int, round (2.5 :: Float) :: Int, ceiling (2.1 :: Float) :: Int, floor (-2.1 :: Float) :: Int)
  print (floatRadix (1 :: Float), exponent (8 :: Float), significand (8 :: Float), scaleFloat 1 (3 :: Float), atan2 0 (1 :: Float))
  print (succ 1.5 :: Float, pred 1.5 :: Float, toEnum 3 :: Float, fromEnum (2.7 :: Float))
  print ([1.0 .. 3.0] :: [Float], [1.0, 1.5 .. 2.0] :: [Float], take 3 [0.5 ..] :: [Float], take 3 [0.5, 0.25 ..] :: [Float])
