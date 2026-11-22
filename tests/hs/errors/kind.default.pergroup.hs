-- Report 4.6: defaults apply to each group whatever its later uses: Tree [] is refused.
module Main (main) where

data Tree a = Leaf | Fork (Tree a) (Tree a)

type FunnyTree = Tree []

main :: IO ()
main = return ()
