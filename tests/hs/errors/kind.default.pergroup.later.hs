-- Report 4.6: the same with the synonym first.
module Main (main) where

type FunnyTree = Tree []

data Tree a = Leaf | Fork (Tree a) (Tree a)

main :: IO ()
main = return ()
