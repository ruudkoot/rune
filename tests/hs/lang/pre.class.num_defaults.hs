-- rows: pre.class.num pre.class.num.plus pre.class.num.minus pre.class.num.star pre.class.num.negate pre.class.num.abs pre.class.num.signum pre.class.num.frominteger
-- Report 8: class Num's defaults: x - y = x + negate y and negate x = 0 - x; every method defined overrides its default.
module Main (main) where

newtype A = A Int deriving (Eq, Ord, Show)
instance Num A where
  A x + A y = A (x + y)
  A x * A y = A (x * y)
  negate (A x) = A (negate x)
  abs (A x) = A (abs x)
  signum (A x) = A (signum x)
  fromInteger n = A (fromInteger n)

newtype B = B Int deriving (Eq, Show)
instance Num B where
  B x + B y = B (x + y)
  B x - B y = B (x - y)
  B x * B y = B (x * y)
  abs (B x) = B (abs x)
  signum (B x) = B (signum x)
  fromInteger n = B (fromInteger n)

newtype C = C Int deriving (Eq, Show)
instance Num C where
  _ + _ = C 1
  _ - _ = C 2
  _ * _ = C 3
  negate _ = C 4
  abs _ = C 5
  signum _ = C 6
  fromInteger _ = C 7

main :: IO ()
main = do
  print (A 5 - A 3, negate (B 4), B 5 - B 3)
  print [C 0 + C 0, C 0 - C 0, C 0 * C 0, negate (C 0), abs (C 0), signum (C 0), 0]
  print (abs (A (-3)), signum (B (-3)), 7 :: A)
