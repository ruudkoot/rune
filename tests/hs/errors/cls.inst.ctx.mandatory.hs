-- Report 4.3.2: an instance context is written, never inferred: the same with Eq.
module Main (main) where

class C a where
  m :: a -> Bool
instance C [a] where
  m (x:y:_) = x == y
  m _ = False

main :: IO ()
main = return ()
