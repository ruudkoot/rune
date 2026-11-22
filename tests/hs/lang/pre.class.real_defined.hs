-- rows: pre.class.real pre.class.real.torational
-- Report 8: class Real has toRational and no default.
module Main (main) where

newtype A = A Int deriving (Eq, Ord, Show)
instance Num A where
  A x + A y = A (x + y)
  A x * A y = A (x * y)
  negate (A x) = A (negate x)
  abs (A x) = A (abs x)
  signum (A x) = A (signum x)
  fromInteger n = A (fromInteger n)

instance Real A where
  toRational (A x) = toRational x

instance Enum A where
  toEnum = A
  fromEnum (A x) = x

main :: IO ()
main = print (toRational (A 3) == 3, toRational (A (-2)) < 0)
