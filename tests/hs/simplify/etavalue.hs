-- Eta where it is free (D48's C): a partial application, behind lets of
-- values, given its arity; and nothing moved under a lambda: g's lambda is
-- behind an expensive let, which keeps its arity and its sharing.
module Main where

addAll :: [Int] -> Int
addAll = foldl (+) 0

compose :: Int -> Int -> Int
compose k = let m = (* k) in (+ 1) . m

g :: Int -> Int -> Int
g k = let t = length [1 .. k * 1000] in \x -> x + t

main :: IO ()
main = do
  print (addAll [1 .. 10], map (compose 3) [1, 2, 3])
  let h = g 5
  print (map h [1, 2, 3])
  addAll `seq` compose 2 `seq` putStrLn "values"
