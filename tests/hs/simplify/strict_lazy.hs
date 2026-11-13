-- M24: what is not strict stays lazy, whatever the analysis makes strict: an argument a branch does not take, a
-- component not taken, an argument a function ignores; and a strict accumulator runs to its end.
module Main (main) where

pick :: Bool -> Int -> Int -> Int
pick c a b = if c then a else b

loop :: Int -> Int -> Int
loop acc 0 = acc
loop acc n = loop (acc + n) (n - 1)

both :: Int -> Int -> Int
both a b = a + b

firstOr :: Int -> [Int] -> Int
firstOr d [] = d
firstOr _ (x : _) = x

main :: IO ()
main = do
  print (pick True 1 undefined)
  print (pick False undefined 2)
  print (loop 0 100000)
  print (fst (1 :: Int, undefined :: Int))
  print (const (5 :: Int) (undefined :: Int))
  print (firstOr undefined [7])
  print (both 3 4)
