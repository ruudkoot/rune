-- Report 4.3.2: a binding of an instance names its method unqualified: not Ix.range = ...
module Main (main) where

import qualified Ix

data T = T deriving (Eq, Ord)
instance Ix.Ix T where
  Ix.range _ = [T]
  index _ _ = 0
  inRange _ _ = True

main :: IO ()
main = return ()
