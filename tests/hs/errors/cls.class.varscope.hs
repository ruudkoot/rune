-- Report 4.3.1: u scopes only over the methods' signatures: the a of an annotation in a default is its own.
module Main (main) where

class C a where
  m :: a -> a
  m x = (x :: a)

main :: IO ()
main = return ()
