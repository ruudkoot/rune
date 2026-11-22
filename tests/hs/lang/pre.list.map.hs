-- rows: pre.list.plusplus pre.list.filter pre.list.concat pre.list.concatmap pre.list.head pre.list.tail pre.list.last pre.list.init pre.list.null pre.list.length pre.list.bangbang pre.list.foldl pre.list.foldl1 pre.list.scanl pre.list.scanl1 pre.list.foldr pre.list.foldr1 pre.list.scanr pre.list.scanr1 pre.list.iterate pre.list.repeat pre.list.replicate pre.list.cycle pre.list.take pre.list.drop pre.list.splitat pre.list.takewhile pre.list.dropwhile pre.list.span pre.list.break pre.list.lines pre.list.words pre.list.unlines pre.list.unwords pre.list.reverse pre.list.and pre.list.or pre.list.any pre.list.all pre.list.elem pre.list.notelem pre.list.lookup pre.list.sum pre.list.product pre.list.maximum pre.list.minimum pre.list.zip pre.list.zip3 pre.list.zipwith pre.list.zipwith3 pre.list.unzip pre.list.unzip3 pre.list.fixity.9bangbang pre.list.fixity.5plusplus pre.list.fixity.4elemcnotelem
-- Report 8.1 (PreludeList): each list function against the Report's own definition, copied under a new name, on samples
-- and on partial lists that show how lazy the definition is; infixl 9 !!, infixr 5 ++, infix 4 elem and notElem.
module Main (main) where

import Char (isSpace)

map' :: (a -> b) -> [a] -> [b]
map' f [] = []
map' f (x : xs) = f x : map' f xs

app :: [a] -> [a] -> [a]
app [] ys = ys
app (x : xs) ys = x : app xs ys

filter' :: (a -> Bool) -> [a] -> [a]
filter' p xs = [x | x <- xs, p x]

concat' :: [[a]] -> [a]
concat' xss = foldr' app [] xss

concatMap' :: (a -> [b]) -> [a] -> [b]
concatMap' f = concat' . map' f

head' :: [a] -> a
head' (x : _) = x
head' [] = error "Prelude.head: empty list"

tail' :: [a] -> [a]
tail' (_ : xs) = xs
tail' [] = error "Prelude.tail: empty list"

last' :: [a] -> a
last' [x] = x
last' (_ : xs) = last' xs
last' [] = error "Prelude.last: empty list"

init' :: [a] -> [a]
init' [x] = []
init' (x : xs) = x : init' xs
init' [] = error "Prelude.init: empty list"

null' :: [a] -> Bool
null' [] = True
null' (_ : _) = False

length' :: [a] -> Int
length' [] = 0
length' (_ : l) = 1 + length' l

index :: [a] -> Int -> a
index xs n | n < 0 = error "Prelude.!!: negative index"
index [] _ = error "Prelude.!!: index too large"
index (x : _) 0 = x
index (_ : xs) n = index xs (n - 1)

foldl' :: (a -> b -> a) -> a -> [b] -> a
foldl' f z [] = z
foldl' f z (x : xs) = foldl' f (f z x) xs

foldl1' :: (a -> a -> a) -> [a] -> a
foldl1' f (x : xs) = foldl' f x xs
foldl1' _ [] = error "Prelude.foldl1: empty list"

scanl' :: (a -> b -> a) -> a -> [b] -> [a]
scanl' f q xs = q : (case xs of
                       [] -> []
                       x : xs -> scanl' f (f q x) xs)

scanl1' :: (a -> a -> a) -> [a] -> [a]
scanl1' f (x : xs) = scanl' f x xs
scanl1' _ [] = []

foldr' :: (a -> b -> b) -> b -> [a] -> b
foldr' f z [] = z
foldr' f z (x : xs) = f x (foldr' f z xs)

foldr1' :: (a -> a -> a) -> [a] -> a
foldr1' f [x] = x
foldr1' f (x : xs) = f x (foldr1' f xs)
foldr1' _ [] = error "Prelude.foldr1: empty list"

scanr' :: (a -> b -> b) -> b -> [a] -> [b]
scanr' f q0 [] = [q0]
scanr' f q0 (x : xs) = f x q : qs
  where qs@(q : _) = scanr' f q0 xs

scanr1' :: (a -> a -> a) -> [a] -> [a]
scanr1' f [] = []
scanr1' f [x] = [x]
scanr1' f (x : xs) = f x q : qs
  where qs@(q : _) = scanr1' f xs

iterate' :: (a -> a) -> a -> [a]
iterate' f x = x : iterate' f (f x)

repeat' :: a -> [a]
repeat' x = xs where xs = x : xs

replicate' :: Int -> a -> [a]
replicate' n x = take' n (repeat' x)

cycle' :: [a] -> [a]
cycle' [] = error "Prelude.cycle: empty list"
cycle' xs = xs' where xs' = xs `app` xs'

take' :: Int -> [a] -> [a]
take' n _ | n <= 0 = []
take' _ [] = []
take' n (x : xs) = x : take' (n - 1) xs

drop' :: Int -> [a] -> [a]
drop' n xs | n <= 0 = xs
drop' _ [] = []
drop' n (_ : xs) = drop' (n - 1) xs

splitAt' :: Int -> [a] -> ([a], [a])
splitAt' n xs = (take' n xs, drop' n xs)

takeWhile' :: (a -> Bool) -> [a] -> [a]
takeWhile' p [] = []
takeWhile' p (x : xs)
  | p x = x : takeWhile' p xs
  | otherwise = []

dropWhile' :: (a -> Bool) -> [a] -> [a]
dropWhile' p [] = []
dropWhile' p xs@(x : xs')
  | p x = dropWhile' p xs'
  | otherwise = xs

span' :: (a -> Bool) -> [a] -> ([a], [a])
span' p [] = ([], [])
span' p xs@(x : xs')
  | p x = (x : ys, zs)
  | otherwise = ([], xs)
  where (ys, zs) = span' p xs'

break' :: (a -> Bool) -> [a] -> ([a], [a])
break' p = span' (not . p)

lines' :: String -> [String]
lines' "" = []
lines' s = let (l, s') = break' (== '\n') s
           in l : case s' of
                    [] -> []
                    (_ : s'') -> lines' s''

words' :: String -> [String]
words' s = case dropWhile' isSpace s of
             "" -> []
             s' -> w : words' s''
               where (w, s'') = break' isSpace s'

unlines' :: [String] -> String
unlines' = concatMap' (++ "\n")

unwords' :: [String] -> String
unwords' [] = ""
unwords' ws = foldr1' (\w s -> w ++ ' ' : s) ws

reverse' :: [a] -> [a]
reverse' = foldl' (flip (:)) []

and', or' :: [Bool] -> Bool
and' = foldr' (&&) True
or' = foldr' (||) False

any', all' :: (a -> Bool) -> [a] -> Bool
any' p = or' . map' p
all' p = and' . map' p

elem', notElem' :: (Eq a) => a -> [a] -> Bool
elem' x = any' (== x)
notElem' x = all' (/= x)

lookup' :: (Eq a) => a -> [(a, b)] -> Maybe b
lookup' key [] = Nothing
lookup' key ((x, y) : xys)
  | key == x = Just y
  | otherwise = lookup' key xys

sum', product' :: (Num a) => [a] -> a
sum' = foldl' (+) 0
product' = foldl' (*) 1

maximum', minimum' :: (Ord a) => [a] -> a
maximum' [] = error "Prelude.maximum: empty list"
maximum' xs = foldl1' max xs
minimum' [] = error "Prelude.minimum: empty list"
minimum' xs = foldl1' min xs

zip' :: [a] -> [b] -> [(a, b)]
zip' = zipWith' (,)

zip3' :: [a] -> [b] -> [c] -> [(a, b, c)]
zip3' = zipWith3' (,,)

zipWith' :: (a -> b -> c) -> [a] -> [b] -> [c]
zipWith' z (a : as) (b : bs) = z a b : zipWith' z as bs
zipWith' _ _ _ = []

zipWith3' :: (a -> b -> c -> d) -> [a] -> [b] -> [c] -> [d]
zipWith3' z (a : as) (b : bs) (c : cs) = z a b c : zipWith3' z as bs cs
zipWith3' _ _ _ _ = []

unzip' :: [(a, b)] -> ([a], [b])
unzip' = foldr' (\(a, b) ~(as, bs) -> (a : as, b : bs)) ([], [])

unzip3' :: [(a, b, c)] -> ([a], [b], [c])
unzip3' = foldr' (\(a, b, c) ~(as, bs, cs) -> (a : as, b : bs, c : cs)) ([], [], [])

u :: Int
u = undefined

xs5 :: [Int]
xs5 = [3, 1, 4, 1, 5]

main :: IO ()
main = do
  print (map (+ 1) xs5 == map' (+ 1) xs5)
  print (head (map (+ 1) (1 : undefined)) == head (map' (+ 1) (1 : undefined)))
  print ([1, 2] ++ [3] == app [1, 2] [3 :: Int])
  print (head ([1] ++ undefined) == head (app [1 :: Int] undefined))
  print (filter odd xs5 == filter' odd xs5)
  print (concat [[1], [2, 3], []] == concat' [[1], [2, 3 :: Int], []])
  print (concatMap (\x -> [x, x]) xs5 == concatMap' (\x -> [x, x]) xs5)
  print (head [1, u] == head' [1, u])
  print (tail xs5 == tail' xs5)
  print (last xs5 == last' xs5)
  print (init xs5 == init' xs5)
  print (take 1 (init (1 : 2 : undefined)) == take 1 (init' (1 : 2 : undefined :: [Int])))
  print ((null [], null (1 : undefined)) == (null' [], null' (1 : undefined :: [Int])))
  print (length [u, u] == length' [u, u])
  print ((xs5 !! 2, (1 : 2 : undefined) !! 1) == (index xs5 2, index (1 : 2 : undefined) (1 :: Int)))
  print (foldl (-) 10 xs5 == foldl' (-) 10 xs5)
  print (foldl1 (-) xs5 == foldl1' (-) xs5)
  print (scanl (-) 10 xs5 == scanl' (-) 10 xs5)
  print (take 3 (scanl (+) 0 [1 ..]) == take 3 (scanl' (+) 0 [1 :: Int ..]))
  print (scanl1 (-) xs5 == scanl1' (-) xs5)
  print (foldr (-) 10 xs5 == foldr' (-) 10 xs5)
  print (foldr (\x _ -> x) 0 (1 : undefined) == foldr' (\x _ -> x) 0 (1 : undefined :: [Int]))
  print (foldr1 (-) xs5 == foldr1' (-) xs5)
  print (scanr (-) 10 xs5 == scanr' (-) 10 xs5)
  print (scanr1 (-) xs5 == scanr1' (-) xs5)
  print (take 4 (iterate (* 2) 1) == take 4 (iterate' (* 2) (1 :: Int)))
  print (take 3 (repeat 'x') == take 3 (repeat' 'x'))
  print ((replicate 3 'y', replicate (-1) 'y') == (replicate' 3 'y', replicate' (-1) 'y'))
  print (take 5 (cycle [1, 2]) == take 5 (cycle' [1, 2 :: Int]))
  print ((take 2 xs5, take 0 (undefined :: [Int]), take 9 xs5, take (-1) xs5) == (take' 2 xs5, take' 0 (undefined :: [Int]), take' 9 xs5, take' (-1) xs5))
  print ((drop 2 xs5, drop 9 xs5, drop (-1) xs5) == (drop' 2 xs5, drop' 9 xs5, drop' (-1) xs5))
  print (splitAt 2 xs5 == splitAt' 2 xs5)
  print (takeWhile (< 3) (1 : 2 : 3 : undefined) == takeWhile' (< 3) (1 : 2 : 3 : undefined :: [Int]))
  print (dropWhile (< 4) xs5 == dropWhile' (< 4) xs5)
  print (span (< 4) xs5 == span' (< 4) xs5)
  print (break (> 3) xs5 == break' (> 3) xs5)
  print (map lines ["a\n\nb", "a\n", "", "\n"] == map lines' ["a\n\nb", "a\n", "", "\n"])
  print (map words [" a  b ", "", "x\ty\nz"] == map words' [" a  b ", "", "x\ty\nz"])
  print (unlines ["a", "b"] == unlines' ["a", "b"])
  print ((unwords ["a", "b"], unwords []) == (unwords' ["a", "b"], unwords' []))
  print (reverse xs5 == reverse' xs5)
  print ((and (False : undefined), or (True : undefined)) == (and' (False : undefined), or' (True : undefined)))
  print ((and [], or []) == (and' [], or' []))
  print ((any (> 4) xs5, all (> 0) xs5) == (any' (> 4) xs5, all' (> 0) xs5))
  print ((elem 1 (1 : undefined), notElem 9 xs5) == (elem' 1 (1 : undefined :: [Int]), notElem' 9 xs5))
  print (lookup 1 ((1, 'a') : undefined) == lookup' 1 ((1 :: Int, 'a') : undefined))
  print (lookup 7 (zip xs5 "abcde") == lookup' 7 (zip xs5 "abcde"))
  print ((sum xs5, product xs5) == (sum' xs5, product' xs5))
  print ((maximum xs5, minimum xs5) == (maximum' xs5, minimum' xs5))
  print ((zip xs5 "ab", zip ([] :: [Int]) (undefined :: [Int]), zip [1] (2 : undefined)) == (zip' xs5 "ab", zip' ([] :: [Int]) (undefined :: [Int]), zip' [1 :: Int] (2 : undefined :: [Int])))
  print (zip3 xs5 "abc" [True] == zip3' xs5 "abc" [True])
  print (zipWith (+) xs5 [10, 20] == zipWith' (+) xs5 [10, 20])
  print (zipWith3 (\a b c -> a + b + c) xs5 xs5 [1] == zipWith3' (\a b c -> a + b + c) xs5 xs5 [1])
  print (unzip (zip xs5 "abc") == unzip' (zip xs5 "abc"))
  print (head (fst (unzip ((1, 'a') : undefined))) == head (fst (unzip' ((1 :: Int, 'a') : undefined))))
  print (unzip3 (zip3 xs5 "ab" [True]) == unzip3' (zip3 xs5 "ab" [True]))
  print ([[1], [2]] !! 1 ++ [3] == [2, 3 :: Int])
  print ((1 `elem` [1 :: Int] && True) == True)
