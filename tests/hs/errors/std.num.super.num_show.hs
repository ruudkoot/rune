-- Report 6.4: nor without Show.
module Main (main) where

data T = T deriving Eq
instance Num T where
  _ + _ = T
  _ * _ = T
  abs = id
  signum = id
  negate = id
  fromInteger _ = T

main :: IO ()
main = return ()
