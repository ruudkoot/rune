-- rows: pre.inst.orddouble pre.inst.numdouble pre.inst.realdouble pre.inst.fractionaldouble pre.inst.floatingdouble pre.inst.realfracdouble pre.inst.realfloatdouble pre.inst.enumdouble
-- Report 8: the instances of Double: Eq, Ord, Num, Real, Fractional, Floating, RealFrac, RealFloat and Enum, each method on
-- sample values that a binary fraction holds exactly, the transcendental ones to a tolerance.
module Main (main) where

near :: Double -> Double -> Bool
near a b = abs (a - b) < 1.0e-4

main :: IO ()
main = do
  print (1.5 == (1.5 :: Double), 1.5 /= (1.5 :: Double), compare 1.5 (2.5 :: Double), max 1.5 (2.5 :: Double), min 1.5 (2.5 :: Double))
  print (1.5 + 2.25 :: Double, 1.5 - 2 :: Double, 1.5 * 2 :: Double, negate 1.5 :: Double, abs (-2.5) :: Double)
  print (signum (-2.5) :: Double, fromInteger 7 :: Double, toRational (0.75 :: Double) == 3 / 4, 7 / 2 :: Double, recip 4 :: Double)
  print (sqrt 4 :: Double, exp 0 :: Double, log 1 :: Double, sin 0 :: Double, cos 0 :: Double)
  print (near pi 3.14159, near (2 ** 3) 8, near (logBase 2 8) 3, near (tan 0) 0, near (atan 1 * 4) pi)
  print (near (asin 1) (pi / 2), near (acos 1) 0, near (sinh 0) 0, near (cosh 0) 1, near (tanh 0) 0)
  print (near (asinh 0) 0, near (acosh 1) 0, near (atanh 0) 0, fromRational (3 / 4) :: Double)
  print (properFraction (3.75 :: Double) :: (Int, Double), truncate (-2.5 :: Double) :: Int, round (2.5 :: Double) :: Int, ceiling (2.1 :: Double) :: Int, floor (-2.1 :: Double) :: Int)
  print (floatRadix (1 :: Double), exponent (8 :: Double), significand (8 :: Double), scaleFloat 1 (3 :: Double), atan2 0 (1 :: Double))
  print (succ 1.5 :: Double, pred 1.5 :: Double, toEnum 3 :: Double, fromEnum (2.7 :: Double))
  print ([1.0 .. 3.0] :: [Double], [1.0, 1.5 .. 2.0] :: [Double], take 3 [0.5 ..] :: [Double], take 3 [0.5, 0.25 ..] :: [Double])
