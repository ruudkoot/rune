-- Report 10.4: the figure's Tree cannot derive Enum.
module Main (main) where

data Tree a = Leaf a | Tree a :^: Tree a deriving Enum

main :: IO ()
main = return ()
