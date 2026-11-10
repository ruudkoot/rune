-- rows: std.exp.logbase std.exp.sqrt std.pow.frac std.pow.float std.pow.zero std.pow.zero.frac std.sign.law std.trig.funcs std.trig.atan2.range std.trig.atan2.one
-- Report 6.4.3 to 6.4.5: exp and log, logBase, sqrt, ^^ and **, x ^ 0 and x ^^ 0 are 1; abs x * signum x == x; the
-- trigonometric functions and atan2's quadrants, to a tolerance.
module Main (main) where

near :: Double -> Double -> Bool
near a b = abs (a - b) < 1.0e-9

nearF :: Float -> Float -> Bool
nearF a b = abs (a - b) < 1.0e-4

main :: IO ()
main = do
  print (near (log (exp 1)) 1, near (logBase 2 8) 3, sqrt 4 :: Double)
  print (2 ^^ (-1) :: Double, near (2 ** 0.5) 1.4142135623730951, 0 ^ 0 :: Int, 0 ^^ 0 :: Double)
  print (and [abs x * signum x == x | x <- [-3, 0, 5 :: Int]], and [abs x * signum x == x | x <- [-2.5, 0, 4 :: Double]], signum (-3 :: Integer), abs (-3 :: Integer))
  print (near (sin (pi / 2)) 1, near (cos 0) 1, near (tan (pi / 4)) 1)
  print (near (asin 1) (pi / 2), near (acos 1) 0, near (atan 1) (pi / 4))
  print (near (sinh 0) 0, near (cosh 0) 1, near (tanh 0) 0)
  print (near (asinh 0) 0, near (acosh 1) 0, near (atanh 0) 0)
  print (nearF (sin (pi / 2)) 1, nearF (exp 0) 1, nearF (sqrt 9) 3)
  print (atan2 1 1 > (0 :: Double), atan2 1 (-1) > pi / (2 :: Double), atan2 (-1) (-1) < - pi / (2 :: Double), atan2 (-1) 1 < (0 :: Double), near (atan2 1 0) (pi / 2))
