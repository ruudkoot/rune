-- rows: lib.r.list.generic.take lib.r.list.generic.drop lib.r.list.generic.splitat lib.r.list.generic.index lib.r.list.generic.replicate lib.r.list.zip R48
-- Report 17.7, 17.8: genericLength :: Integral a => [b] -> a, at Integer and Int; genericTake, genericDrop and
-- genericSplitAt, a negative count as 0 (erratum September 2008); genericIndex and genericReplicate; zip, zipWith
-- and unzip of 4 to 7 lists, tuples shown as lists.
module Main (main) where

import List

l4 :: (a, a, a, a) -> [a]
l4 (a, b, c, d) = [a, b, c, d]

l5 :: (a, a, a, a, a) -> [a]
l5 (a, b, c, d, e) = [a, b, c, d, e]

l6 :: (a, a, a, a, a, a) -> [a]
l6 (a, b, c, d, e, f) = [a, b, c, d, e, f]

l7 :: (a, a, a, a, a, a, a) -> [a]
l7 (a, b, c, d, e, f, g) = [a, b, c, d, e, f, g]

u4 :: ([a], [a], [a], [a]) -> [[a]]
u4 (a, b, c, d) = [a, b, c, d]

u7 :: ([a], [a], [a], [a], [a], [a], [a]) -> [[a]]
u7 (a, b, c, d, e, f, g) = [a, b, c, d, e, f, g]

main :: IO ()
main = do
  print (genericLength "abc" :: Integer, genericLength [1, 2 :: Int] :: Int, genericLength "" :: Integer, genericLength (replicate 3 ()) + (1 :: Int))
  print (genericTake (2 :: Integer) "abc", genericTake (-1 :: Integer) "abc", genericTake (5 :: Int) "ab", genericTake (0 :: Integer) "abc")
  print (genericDrop (2 :: Integer) "abc", genericDrop (-1 :: Integer) "abc", genericDrop (5 :: Int) "ab")
  print (genericSplitAt (2 :: Integer) "abc", genericSplitAt (-1 :: Integer) "abc", genericSplitAt (5 :: Int) "ab")
  print (genericIndex "abc" (2 :: Integer), genericIndex [10, 20 :: Int] (0 :: Int), genericIndex [1 :: Int ..] (100 :: Integer))
  print (genericReplicate (3 :: Integer) 'x', genericReplicate (0 :: Int) 'x', genericReplicate (-2 :: Integer) 'x')
  print (map l4 (zip4 [1, 2] [3, 4] [5, 6] [7, 8 :: Int]), map l5 (zip5 "ab" "cd" "ef" "gh" "i"), map l6 (zip6 [1] [2] [3] [4] [5] [6 :: Int]))
  print (map l7 (zip7 "abc" "def" "ghi" "jkl" "mno" "pqr" "stu"))
  print (zipWith4 (\a b c d -> a + b + c + d) [1, 2] [3] [4, 5] [6 :: Int], zipWith5 (\a b c d e -> [a, b, c, d, e]) "ab" "cd" "ef" "gh" "ij")
  print (zipWith6 (\a b c d e f -> a * b * c * d * e * f) [1, 2] [3, 4] [5, 6] [7, 8] [9, 10] [11, 12 :: Integer], zipWith7 (\a b c d e f g -> [a, b, c, d, e, f, g]) "a" "b" "c" "d" "e" "f" "g")
  print (u4 (unzip4 [(1, 2, 3, 4), (5, 6, 7, 8 :: Int)]), u7 (unzip7 [('a', 'b', 'c', 'd', 'e', 'f', 'g'), ('h', 'i', 'j', 'k', 'l', 'm', 'n')]))
  print (let (a, b, c, d, e) = unzip5 [(1 :: Int, 'x', True, "s", 2.5 :: Double), (2, 'y', False, "t", 0.5)] in (a, b, c, d, e))
  print (let (a, b, c, d, e, f) = unzip6 ([(1, 2, 3, 4, 5, 6)] :: [(Int, Int, Int, Int, Int, Int)]) in [a, b, c, d, e, f])
