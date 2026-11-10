-- Report 4.3.1: a method has not the name of a field.
module Main (main) where

class C a where
  x :: a -> Int

data R = R { x :: Int }

main :: IO ()
main = return ()
