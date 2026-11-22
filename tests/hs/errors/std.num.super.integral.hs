-- Report 6.4: Integral is a subclass of Real and Enum: no Integral without Enum.
module Main (main) where

newtype T = T Integer deriving (Eq, Ord, Show)
instance Num T where
  T a + T b = T (a + b)
  T a * T b = T (a * b)
  abs = id
  signum = id
  negate (T a) = T (negate a)
  fromInteger = T
instance Real T where
  toRational (T a) = toRational a
instance Integral T where
  quotRem (T a) (T b) = (T (quot a b), T (rem a b))
  toInteger (T a) = a

main :: IO ()
main = return ()
