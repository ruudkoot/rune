-- rows: lib.r.list.unfoldr.undo lib.r.list.isprefixof lib.r.list.issuffixof
-- Report 17.4, 17.5: iterate f == unfoldr (\x -> Just (x, f x)); unfoldr f' (foldr f z xs) == xs where f' (f x y) = Just
-- (x,y) and f' z = Nothing (f x y = x + 10 * y on digits 1 to 9, z = 0, and (:) with []); isPrefixOf and isSuffixOf
-- check a prefix and a suffix (a prefix of an infinite list too).
module Main (main) where

import List

f :: Int -> Int -> Int
f x y = x + 10 * y

f' :: Int -> Maybe (Int, Int)
f' n = if n == 0 then Nothing else Just (n `mod` 10, n `div` 10)

unc :: [a] -> Maybe (a, [a])
unc [] = Nothing
unc (c : cs) = Just (c, cs)

main :: IO ()
main = do
  print (take 5 (iterate (* 2) 1) == take 5 (unfoldr (\x -> Just (x, x * 2)) (1 :: Int)), take 5 (unfoldr (\x -> Just (x, x * 2)) (1 :: Int)), take 4 (iterate (++ "a") "") == take 4 (unfoldr (\x -> Just (x, x ++ "a")) ""))
  print (and [unfoldr f' (foldr f 0 xs) == xs | xs <- [[], [3], [3, 1, 4, 1, 5], [9, 9, 1]]], unfoldr f' (foldr f 0 [3, 1, 4]), and [unfoldr unc (foldr (:) [] xs) == xs | xs <- ["", "abc"]])
  print (unfoldr (\n -> if n > 5 then Nothing else Just (n * n, n + 1)) (1 :: Int))
  print (isPrefixOf "ab" "abc", isPrefixOf "abc" "ab", isPrefixOf "" "", isPrefixOf "b" "abc", isPrefixOf [1, 2] [1 :: Int ..])
  print (isSuffixOf "bc" "abc", isSuffixOf "abc" "bc", isSuffixOf "" "x", isSuffixOf "b" "abc", "abc" `isSuffixOf` "abc")
