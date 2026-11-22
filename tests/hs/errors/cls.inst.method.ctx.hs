-- Report 4.3.2: the instance context satisfies the methods' constraints: show x needs Show a.
module Main (main) where

class C a where
  m :: a -> String
instance C [a] where
  m (x:_) = show x
  m [] = ""

main :: IO ()
main = return ()
