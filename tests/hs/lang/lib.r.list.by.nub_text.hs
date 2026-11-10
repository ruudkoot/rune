-- rows: lib.r.list.by.delete lib.r.list.by.deletefirsts lib.r.list.by.union lib.r.list.by.intersect lib.r.list.by.group lib.r.list.by.sort lib.r.list.by.insert lib.r.list.by.maximum lib.r.list.by.minimum
-- Report 17.6: the By variants, with the text's nub and nubBy as references, each with an equivalence or a total ordering
-- on a type of no Eq or Ord instance (P), in place of Eq's or Ord's.
module Main (main) where

import List

data P = P Int Char

sameN :: P -> P -> Bool
sameN (P a _) (P b _) = a == b

byN :: P -> P -> Ordering
byN (P a _) (P b _) = compare a b

sh :: [P] -> String
sh xs = [c | P _ c <- xs]

ps, qs :: [P]
ps = [P 2 'a', P 1 'b', P 2 'c', P 3 'd', P 1 'e']
qs = [P 1 'x', P 4 'y', P 4 'z']

nubText :: (Eq a) => [a] -> [a]
nubText [] = []
nubText (x:xs) = x : nubText (filter (\y -> not (x == y)) xs)

nubByText :: (a -> a -> Bool) -> [a] -> [a]
nubByText eq [] = []
nubByText eq (x:xs) = x : nubByText eq (filter (\y -> not (eq x y)) xs)

main :: IO ()
main = do
  print (sh (nubBy sameN ps), sh (nubByText sameN ps), and [nub xs == nubText xs && nubBy (\a b -> a `mod` 3 == b `mod` 3) xs == nubByText (\a b -> a `mod` 3 == b `mod` 3) xs | xs <- [[], [1, 3, 1, 4, 3, 3], [5, 2, 8, 1 :: Int]]])
  print (sh (deleteBy sameN (P 2 'q') ps), sh (deleteBy sameN (P 9 'q') ps), sh (deleteFirstsBy sameN ps qs))
  print (sh (unionBy sameN ps qs), sh (unionBy sameN qs ps), sh (intersectBy sameN ps qs))
  print (map sh (groupBy sameN [P 1 'a', P 1 'b', P 2 'c', P 1 'd']), groupBy (\a b -> even a == even b) [2, 4, 1, 3, 6 :: Int])
  print (sh (sortBy byN ps), sh (insertBy byN (P 2 'n') (sortBy byN ps)), sortBy (flip compare) [3, 1, 2 :: Int])
  print (sh [maximumBy byN ps], sh [minimumBy byN ps], maximumBy (\a b -> compare (snd a) (snd b)) [(1, 'z'), (2, 'a') :: (Int, Char)])
