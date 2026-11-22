-- rows: lib.r.list.example.transpose lib.r.list.partition lib.r.list.sort.stable lib.r.list.insert lib.r.list.example.group lib.r.list.example.inits lib.r.list.example.tails lib.r.list.mapaccuml lib.r.list.mapaccumr
-- Report 17.3: the transformations on the text's examples: intersperse ',' "abcde" == "a,b,c,d,e", transpose
-- [[1,2,3],[4,5,6]] == [[1,4],[2,5],[3,6]], partition p xs == (filter p xs, filter (not . p) xs) (on an infinite
-- list too), a stable sort, insert into an ordered list, group "Mississippi", inits "abc" (shortest first, on an
-- infinite list too), tails "abc" (longest first), mapAccumL left to right and mapAccumR right to left.
module Main (main) where

import List

main :: IO ()
main = do
  print (intersperse ',' "abcde", intersperse ',' "abcde" == "a,b,c,d,e", intersperse 0 [1 :: Int], intersperse 'x' "")
  print (transpose [[1, 2, 3], [4, 5, 6 :: Int]], transpose [[1, 2, 3], [4, 5, 6 :: Int]] == [[1, 4], [2, 5], [3, 6]], transpose [[1, 2], [3, 4, 5], [] :: [Int]], transpose ["abc", "d"])
  print (partition even [1 .. 10 :: Int], and [partition p xs == (filter p xs, filter (not . p) xs) | p <- [even, (> 3), const True], xs <- [[], [1 .. 7], [4, 4, 1 :: Int]]])
  print (take 3 (fst (partition even [1 :: Int ..])), take 3 (snd (partition even [1 :: Int ..])))
  print (sortBy (\a b -> compare (fst a) (fst b)) [(2, 'a'), (1, 'b'), (2, 'c'), (1, 'd'), (0, 'e') :: (Int, Char)], sort [3, 1, 2, 1 :: Int], sort "hello")
  print (insert 3 [1, 2, 4, 5 :: Int], insert 0 [1, 2 :: Int], insert 9 [1, 2 :: Int], insert 'c' "abde", take 4 (insert 3 [1 :: Int ..]))
  print (group "Mississippi", group "Mississippi" == ["M", "i", "ss", "i", "ss", "i", "pp", "i"], group ([] :: [Int]), take 3 (group (cycle "aab")))
  print (inits "abc", inits "abc" == ["", "a", "ab", "abc"], take 4 (inits [1 :: Int ..]), inits "")
  print (tails "abc", tails "abc" == ["abc", "bc", "c", ""], tails "", map (take 2) (take 3 (tails [1 :: Int ..])))
  print (mapAccumL (\s x -> (s + x, s * x)) 0 [1 .. 5 :: Int], mapAccumL (\s c -> (s ++ [c], length s)) "" "abc")
  print (mapAccumR (\s x -> (s + x, s * x)) 0 [1 .. 5 :: Int], mapAccumR (\s c -> (s ++ [c], length s)) "" "abc")
