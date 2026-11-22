-- Report 6.4: Real is a subclass of Num and Ord: no Real without Ord.
module Main (main) where

newtype T = T Integer deriving (Eq, Show)
instance Num T where
  T a + T b = T (a + b)
  T a * T b = T (a * b)
  abs = id
  signum = id
  negate (T a) = T (negate a)
  fromInteger = T
instance Real T where
  toRational (T a) = toRational a

main :: IO ()
main = return ()
