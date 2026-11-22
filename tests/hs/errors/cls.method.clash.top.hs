-- Report 4.3.1: a method has not the name of a top-level definition.
module Main (main) where

class C a where
  x :: a -> Int

x :: Int
x = 1

main :: IO ()
main = return ()
