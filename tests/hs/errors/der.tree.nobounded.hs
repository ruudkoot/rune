-- Report 10.4: nor Bounded.
module Main (main) where

data Tree a = Leaf a | Tree a :^: Tree a deriving Bounded

main :: IO ()
main = return ()
