-- rows: pre.class.realfloat pre.class.realfloat.floatradix pre.class.realfloat.floatdigits pre.class.realfloat.floatrange pre.class.realfloat.decodefloat pre.class.realfloat.encodefloat pre.class.realfloat.exponent pre.class.realfloat.significand pre.class.realfloat.scalefloat pre.class.realfloat.atan2
-- Report 8: class RealFloat's defaults: exponent, significand and scaleFloat from decodeFloat and encodeFloat, and
-- atan2 by quadrant; the rest are the instance's; every method defined overrides its default.
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
instance RealFrac A where
  properFraction (A x) = case properFraction x of (n, f) -> (n, A f)
instance RealFloat A where
  floatRadix (A x) = floatRadix x
  floatDigits (A x) = floatDigits x
  floatRange (A x) = floatRange x
  decodeFloat (A x) = decodeFloat x
  encodeFloat m n = A (encodeFloat m n)
  isNaN (A x) = isNaN x
  isInfinite (A x) = isInfinite x
  isDenormalized (A x) = isDenormalized x
  isNegativeZero (A x) = isNegativeZero x
  isIEEE (A x) = isIEEE x

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
  pi = C pi
  exp (C x) = C (exp x)
  log (C x) = C (log x)
  sin (C x) = C (sin x)
  cos (C x) = C (cos x)
  asin (C x) = C (asin x)
  acos (C x) = C (acos x)
  atan (C x) = C (atan x)
  sinh (C x) = C (sinh x)
  cosh (C x) = C (cosh x)
  asinh (C x) = C (asinh x)
  acosh (C x) = C (acosh x)
  atanh (C x) = C (atanh x)
instance RealFrac C where
  properFraction (C x) = case properFraction x of (n, f) -> (n, C f)
instance RealFloat C where
  floatRadix _ = 1
  floatDigits _ = 2
  floatRange _ = (3, 4)
  decodeFloat _ = (5, 6)
  encodeFloat _ _ = C 7
  isNaN _ = False
  isInfinite _ = False
  isDenormalized _ = False
  isNegativeZero _ = False
  isIEEE _ = False
  exponent _ = 8
  significand _ = C 9
  scaleFloat _ _ = C 10
  atan2 _ _ = C 11

un :: A -> Double
un (A x) = x

main :: IO ()
main = do
  print (exponent (A 8), significand (A 8), scaleFloat 2 (A 3))
  print [un (atan2 (A 1) (A 1)) == atan 1, un (atan2 (A 1) (A (-1))) == atan (1 / (-1)) + pi, un (atan2 (A (-1)) (A 0)) == - pi / 2]
  print (floatRadix (C 0), floatDigits (C 0), floatRange (C 0), decodeFloat (C 0), encodeFloat 0 0 :: C)
  print (exponent (C 0), significand (C 0), scaleFloat 0 (C 0), atan2 (C 0) (C 0))
