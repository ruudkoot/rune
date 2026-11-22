-- Report 6.4: Floating is a subclass of Fractional: no Floating without Fractional.
module Main (main) where

data T = T deriving (Eq, Show)
instance Num T where
  _ + _ = T
  _ * _ = T
  abs = id
  signum = id
  negate = id
  fromInteger _ = T
instance Floating T where
  pi = T
  exp = id
  log = id
  sin = id
  cos = id
  asin = id
  acos = id
  atan = id
  sinh = id
  cosh = id
  asinh = id
  acosh = id
  atanh = id

main :: IO ()
main = return ()
