-- rows: pre.class.fractional pre.class.fractional.slash pre.class.fractional.recip pre.class.fractional.fromrational
-- Report 8: class Fractional's defaults: recip x = 1 / x and x / y = x * recip y; every method defined overrides its default.
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

newtype B = B Double deriving (Eq, Ord, Show)
instance Num B where
  B x + B y = B (x + y)
  B x * B y = B (x * y)
  negate (B x) = B (negate x)
  abs (B x) = B (abs x)
  signum (B x) = B (signum x)
  fromInteger n = B (fromInteger n)
instance Real B where
  toRational (B x) = toRational x

instance Fractional B where
  recip (B x) = B (recip x)
  fromRational r = B (fromRational r)

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
  _ / _ = C 1
  recip _ = C 2
  fromRational _ = C 3

main :: IO ()
main = do
  print (recip (A 4), A 1 / A 4, B 1 / B 4, recip (B 4))
  print (C 0 / C 0, recip (C 0), 0.5 :: C, 0.5 :: A)
