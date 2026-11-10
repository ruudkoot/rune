-- Report 4.5.1: reorder.where.hs with the declarations of its where and its let in the reverse order.
module Main (main) where

r :: Int -> Int
r n = p + q
  where q = n + 1
        p = q * n

main :: IO ()
main = do
  print (r 3)
  print (let c = 5; b = c * 2; a = b + 1 in a :: Int)
