-- Report 4.3.2: nor a method of another class.
module Main (main) where

class C a where
  m :: a -> Int
class D a where
  d :: a -> Int
instance C Bool where
  m _ = 0
  d _ = 1

main :: IO ()
main = return ()
