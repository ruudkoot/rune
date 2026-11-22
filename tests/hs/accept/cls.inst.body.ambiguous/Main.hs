-- Report 4.3.2: a method binding resolves through its class, so it does not matter that its unqualified name is
-- also another import's: range here is Mine's, and the instance's range is Ix's.
module Main (main) where

import qualified Ix
import Mine (range)

data T = T0 | T1 deriving (Eq, Ord, Show)

instance Ix.Ix T where
  range (a, b) = filter (\t -> a <= t && t <= b) [T0, T1]
  index (a, _) i = if i == a then 0 else 1
  inRange (a, b) i = a <= i && i <= b

main :: IO ()
main = print (Ix.range (T0, T1), range)
