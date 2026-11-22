-- Report 4.3.1: a method has not the name of another class's method.
module Main (main) where

class C a where
  x :: a -> Int
class D a where
  x :: a -> Bool

main :: IO ()
main = return ()
