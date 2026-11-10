-- Report 6.4: RealFrac is a subclass of Real and Fractional: none without Real.
module Main (main) where

data T = T deriving (Eq, Ord, Show)
instance Num T where
  _ + _ = T
  _ * _ = T
  abs = id
  signum = id
  negate = id
  fromInteger _ = T
instance Fractional T where
  _ / _ = T
  fromRational _ = T
instance RealFrac T where
  properFraction _ = (0, T)

main :: IO ()
main = return ()
