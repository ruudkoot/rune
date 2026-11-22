-- Report 6.4: Fractional is a subclass of Num: no Fractional without Num.
module Main (main) where

data T = T deriving (Eq, Show)
instance Fractional T where
  _ / _ = T
  fromRational _ = T

main :: IO ()
main = return ()
