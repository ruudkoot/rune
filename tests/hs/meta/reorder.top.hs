-- rows: dec.dep.order dec.scope.decls.top
-- Report 4, 4.5.1, 5: the order of a module's top-level declarations is irrelevant: fixity, data, class, instance,
-- signatures and bindings; reorder.top.pair.hs has them in the reverse order.
module Main (main) where

infixl 6 <+>

data Shape = Circle Int | Square Int

class Area a where
  area :: a -> Int

instance Area Shape where
  area (Circle r) = 3 * r * r
  area (Square s) = s * s

(<+>) :: Int -> Int -> Int
a <+> b = a + b

total :: [Shape] -> Int
total = foldr (\s acc -> area s <+> acc) 0

main :: IO ()
main = print (total [Circle 1, Square 2] <+> 1 * 2)
