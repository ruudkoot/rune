-- A lazy pattern matches without forcing anything (3.17.2): its value is
-- taken apart only when a variable it binds is demanded. Sestoft's trees
-- (D34's B) leave it alone too.
-- sestoft: as A
module Main where

l :: [Int] -> Bool -> Int
l ~(x:_) True = 1
l _ False = 2

l2 :: [Int] -> Bool -> Int
l2 ~(x:_) True = x
l2 _ _ = 0

main :: IO ()
main = do
  print (l [] True)
  print (l undefined False)
  print (l2 [5] True)
  print (l2 [] False)
  print (l2 [] True)
