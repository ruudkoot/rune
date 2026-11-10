-- rows: lib.r.list.setinvariant lib.r.list.example.delete lib.r.list.difference lib.r.list.difference.law lib.r.list.example.union lib.r.list.example.intersect
-- Report 17.2: the "set" operations on the text's examples: nub [1,3,1,4,3,3] = [1,3,4], delete 'a' "banana" == "bnana",
-- "dog" `union` "cow" == "dogcw", [1,2,3,4] `intersect` [2,4,6,8] == [2,4]; xs \\ ys removes the first occurrence
-- of each element of ys in turn, so (xs ++ ys) \\ xs == ys; and a first argument without duplicates gives a result
-- without, for delete, (\\), union, intersect and their By variants (with an equivalence, duplicates by it).
module Main (main) where

import List

free, any3 :: [[Int]]
free = [[], [1], [3, 1, 2], [5, 4, 3, 2, 1], [0, 2, 4, 6], [7, 1]]
any3 = [[], [1, 1], [2, 2, 1, 3, 3, 1], [4, 0, 4], [9]]

free3 :: [[Int]]
free3 = [[], [1], [0, 1, 2], [5, 3], [4]]

mod3 :: Int -> Int -> Bool
mod3 x y = x `mod` 3 == y `mod` 3

distinctBy :: (a -> a -> Bool) -> [a] -> Bool
distinctBy eq xs = length (nubBy eq xs) == length xs

headOr :: [Int] -> Int
headOr b = if null b then 0 else head b

main :: IO ()
main = do
  print (nub [1, 3, 1, 4, 3, 3 :: Int], nub [1, 3, 1, 4, 3, 3 :: Int] == [1, 3, 4], nub "", nub "mississippi")
  print (delete 'a' "banana", delete 'a' "banana" == "bnana", delete 'z' "abc", delete 3 [3, 3 :: Int])
  print ([1, 2, 1, 3, 1] \\ [1, 1 :: Int], "abcabc" \\ "cba", [1, 2, 3] \\ [4, 2, 2 :: Int], "banana" \\ "")
  print (and [(xs ++ ys) \\ xs == ys | xs <- free ++ any3, ys <- free ++ any3])
  print ("dog" `union` "cow", ("dog" `union` "cow") == "dogcw", [1, 2] `union` [2, 3, 3, 1, 4 :: Int], "aab" `union` "bcc")
  print ([1, 2, 3, 4] `intersect` [2, 4, 6, 8 :: Int], ([1, 2, 3, 4] `intersect` [2, 4, 6, 8 :: Int]) == [2, 4], [1, 1, 2] `intersect` [1 :: Int], "abc" `intersect` "")
  print (and [distinctBy (==) (f xs ys) | xs <- free, ys <- free ++ any3, f <- [\a b -> delete (headOr b) a, (\\), union, intersect]])
  print (and [distinctBy mod3 (f xs ys) | xs <- free3, ys <- free ++ any3, f <- [\a b -> deleteBy mod3 (headOr b) a, deleteFirstsBy mod3, unionBy mod3, intersectBy mod3]])
