-- rows: der.tree.ord.le
-- Report 10.4: the Tree of the figure derives Ord: its methods against the order the declaration gives, Leaf before :^:.
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a deriving (Eq, Ord, Show, Read)

main :: IO ()
main = do
  print (Leaf 1 < Leaf 2 :^: Leaf (3 :: Int), compare (Leaf 2 :^: Leaf 1) (Leaf 2 :^: Leaf (3 :: Int)), Leaf (5 :: Int) <= Leaf 5)
