-- Report 4, 4.5.1, 5: reorder.top.hs with its top-level declarations in the reverse order.
module Main (main) where

main :: IO ()
main = print (total [Circle 1, Square 2] <+> 1 * 2)

total :: [Shape] -> Int
total = foldr (\s acc -> area s <+> acc) 0

a <+> b = a + b
(<+>) :: Int -> Int -> Int

instance Area Shape where
  area (Circle r) = 3 * r * r
  area (Square s) = s * s

class Area a where
  area :: a -> Int

data Shape = Circle Int | Square Int

infixl 6 <+>
