-- Report 3.3, 3.12: rename.locals.hs with every bound variable renamed.
module Main (main) where

f :: Int -> Int
f p = let q = p * 2 in q + k p
  where k w = w - 1

h :: [Int] -> Int
h ys = case ys of
  (c : ds) -> c + sum (map (\e -> e * 10) ds)
  [] -> 0

main :: IO ()
main = do
  print (f 5, h [1, 2, 3])
  print (let u = 1; v = u + 1 in (\w -> w + v) (10 :: Int))
