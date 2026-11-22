-- rows: dec.dep.order
-- Report 4.5.1: the order of the declarations of a where or a let is irrelevant; reorder.where.pair.hs has them
-- in the reverse order.
module Main (main) where

r :: Int -> Int
r n = p + q
  where p = q * n
        q = n + 1

main :: IO ()
main = do
  print (r 3)
  print (let a = b + 1; b = c * 2; c = 5 in a :: Int)
