-- Report 6.4: Num is a subclass of Eq and Show: no Num without Eq.
module Main (main) where

data T = T
instance Show T where
  show _ = "T"
instance Num T where
  _ + _ = T
  _ * _ = T
  abs = id
  signum = id
  negate = id
  fromInteger _ = T

main :: IO ()
main = return ()
