-- rows: std.trig.defaults pre.class.floating pre.class.floating.pi pre.class.floating.exp pre.class.floating.log pre.class.floating.sqrt pre.class.floating.starstar pre.class.floating.logbase pre.class.floating.sin pre.class.floating.cos pre.class.floating.tan pre.class.floating.asin pre.class.floating.acos pre.class.floating.atan pre.class.floating.sinh pre.class.floating.cosh pre.class.floating.tanh pre.class.floating.asinh pre.class.floating.acosh pre.class.floating.atanh
-- Report 8: class Floating's defaults: x ** y = exp (log x * y), logBase x y = log y / log x, sqrt x = x ** 0.5,
-- tan x = sin x / cos x, tanh x = sinh x / cosh x; the rest are the instance's; every method defined overrides
-- its default.
module Main (main) where

newtype A = A Double deriving (Eq, Ord, Show)
instance Num A where
  A x + A y = A (x + y)
  A x * A y = A (x * y)
  negate (A x) = A (negate x)
  abs (A x) = A (abs x)
  signum (A x) = A (signum x)
  fromInteger n = A (fromInteger n)
instance Real A where
  toRational (A x) = toRational x

instance Fractional A where
  A x / A y = A (x / y)
  fromRational r = A (fromRational r)
instance Floating A where
  pi = A pi
  exp (A x) = A (exp x)
  log (A x) = A (log x)
  sin (A x) = A (sin x)
  cos (A x) = A (cos x)
  asin (A x) = A (asin x)
  acos (A x) = A (acos x)
  atan (A x) = A (atan x)
  sinh (A x) = A (sinh x)
  cosh (A x) = A (cosh x)
  asinh (A x) = A (asinh x)
  acosh (A x) = A (acosh x)
  atanh (A x) = A (atanh x)

newtype C = C Double deriving (Eq, Ord, Show)
instance Num C where
  C x + C y = C (x + y)
  C x * C y = C (x * y)
  negate (C x) = C (negate x)
  abs (C x) = C (abs x)
  signum (C x) = C (signum x)
  fromInteger n = C (fromInteger n)
instance Real C where
  toRational (C x) = toRational x

instance Fractional C where
  C x / C y = C (x / y)
  fromRational r = C (fromRational r)
instance Floating C where
  pi = C 0
  exp _ = C 1
  log _ = C 2
  sqrt _ = C 3
  _ ** _ = C 4
  logBase _ _ = C 5
  sin _ = C 6
  cos _ = C 7
  tan _ = C 8
  asin _ = C 9
  acos _ = C 10
  atan _ = C 11
  sinh _ = C 12
  cosh _ = C 13
  tanh _ = C 14
  asinh _ = C 15
  acosh _ = C 16
  atanh _ = C 17

un :: A -> Double
un (A x) = x

main :: IO ()
main = do
  print [un (A 2 ** A 3) == exp (log 2 * 3), un (logBase (A 2) (A 8)) == log 8 / log 2, un (sqrt (A 4)) == exp (log 4 * 0.5)]
  print [un (tan (A 1)) == sin 1 / cos 1, un (tanh (A 1)) == sinh 1 / cosh 1, un (exp (A 1)) == exp 1, un pi == pi]
  print [pi, exp 0, log 0, sqrt 0, 0 ** 0, logBase 0 0, sin 0, cos 0, tan 0 :: C]
  print [asin 0, acos 0, atan 0, sinh 0, cosh 0, tanh 0, asinh 0, acosh 0, atanh 0 :: C]
