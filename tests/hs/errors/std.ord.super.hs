-- Report 6.3.2: Ord has the superclass Eq: no Ord T without Eq T.
module Main (main) where

data T = T
instance Ord T where
  compare _ _ = EQ

main :: IO ()
main = return ()
