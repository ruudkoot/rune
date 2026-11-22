-- rows: der.tree.read.alternatives
-- Report 10.4: the derived reader of the figure's Tree tries the infix alternative before Leaf, so reads gives the longer
-- parse first.
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a deriving (Eq, Show, Read)

main :: IO ()
main = print (reads "Leaf 1 :^: Leaf 2" :: [(Tree Int, String)])
