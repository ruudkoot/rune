-- Report 4.2.1: field names share the top-level namespace: a field x and a method x.
module Main (main) where

data A = A { x :: Int }

class C a where
  x :: a -> Int

main :: IO ()
main = return ()
