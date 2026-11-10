-- Report 4.3.1: nor for a method of another class.
module Main (main) where

class D a where
  d :: a -> a

class C a where
  m :: a -> a
  d x = x

main :: IO ()
main = return ()
