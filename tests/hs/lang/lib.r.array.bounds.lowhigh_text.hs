-- rows: lib.r.array.assoc lib.r.array.strict.values lib.r.array.recurrence lib.r.array.example.scale lib.r.array.example.invperm lib.r.array.subscript lib.r.array.bounds lib.r.array.indices lib.r.array.elems lib.r.array.assocs lib.r.array.listarray lib.r.array.empty.legal lib.r.array.empty.bounds lib.r.array.accumarray lib.r.array.accumarray.args lib.r.array.hist lib.r.array.update lib.r.array.update.diag lib.r.array.accum lib.r.array.accum.identity lib.r.array.fmap lib.r.array.ixmap lib.r.array.example.subarray lib.r.array.example.row lib.r.array.example.diag lib.r.array.example.firstarray lib.r.array.show lib.r.array.eq
-- Report 16.1 to 16.3: the text's statements of Array on its examples: bounds lowest and highest, associations read back
-- in index order, nonstrict values and the recurrence a = array (1,100) ((1,1) : [(i, i * a!(i-1)) | ...]), the
-- examples of Figures 16.1 and 16.2, empty arrays, accumArray and hist, (//) and accum, fmap and ixmap, show and
-- read. An element defined twice, or never, is bottom alone: the others stay readable. The expected output is the
-- Report's code's.
module Main (main) where

import Array

scale :: (Num a, Ix b) => a -> Array b a -> Array b a
scale x a = array b [(i, a ! i * x) | i <- range b]
  where b = bounds a

invPerm :: (Ix a) => Array a a -> Array a a
invPerm a = array b [(a ! i, i) | i <- range b]
  where b = bounds a

inner :: (Ix a, Num b) => Array a b -> Array a b -> b
inner v w = if b == bounds w then sum [v ! i * w ! i | i <- range b]
            else error "inconformable arrays for inner product"
  where b = bounds v

hist :: (Ix a, Num b) => (a, a) -> [a] -> Array a b
hist bnds is = accumArray (+) 0 bnds [(i, 1) | i <- is, inRange bnds i]

subArray :: (Ix a) => (a, a) -> Array a b -> Array a b
subArray bnds = ixmap bnds (\i -> i)

row :: (Ix a, Ix b) => a -> Array (a, b) c -> Array b c
row i x = ixmap (l', u') (\j -> (i, j)) x where ((_, l'), (_, u')) = bounds x

diag :: (Ix a) => Array (a, a) b -> Array a b
diag x = ixmap (l, u) (\i -> (i, i)) x
  where ((l, _), (u, _)) = bounds x

firstArray :: (Ix a) => Array a (b, c) -> Array a b
firstArray = fmap (\(x, y) -> x)

fact :: Array Int Integer
fact = array (1, 100) ((1, 1) : [(i, toInteger i * fact ! (i - 1)) | i <- [2 .. 100]])

m3 :: Array (Int, Int) Int
m3 = listArray ((1, 1), (3, 3)) [1 ..]

main :: IO ()
main = do
  print (bounds (array (1, 10) [] :: Array Int Char), bounds (listArray ((1, 1), (10, 10)) [] :: Array (Int, Int) Char))
  print (array (1, 3) [(3, 'c'), (1, 'a'), (2, 'b')] ! 1, indices (array (1, 3) [(3, 'c'), (1, 'a'), (2, 'b')]), elems (array (1, 3) [(3, 'c'), (1, 'a'), (2, 'b')]))
  print (assocs (array (1, 3) [(3, 'c'), (2, 'b'), (1, 'a')]), listArray (0, 2) "xyz" ! 2)
  print (array (1, 1) [(1, undefined :: Int)] `seq` (), bounds (array (2, 1) [] :: Array Int Char), array (2, 1) [] `seq` ())
  print (fact ! 20, fact ! 100 `mod` 1000000007)
  print (scale 2 (listArray (0, 2) [1, 2, 3 :: Int]), invPerm (listArray (1, 3) [2, 3, 1 :: Int]))
  print (inner (listArray (1, 3) [1, 2, 3]) (listArray (1, 3) [4, 5, 6 :: Int]))
  print (hist (0, 3) [1, 3, 1, 9, 0, 1 :: Int] :: Array Int Int)
  print (accumArray (\acc x -> acc * 10 + x) 0 (1, 2) [(1, 1), (1, 2), (2, 3)] :: Array Int Int, accumArray (+) 7 (0, 1) [] :: Array Int Int)
  print (accumArray (+) 0 (0, 2) [(1, 5), (1, 6)] == accum (+) (array (0, 2) [(i, 0) | i <- range (0, 2)]) [(1, 5), (1, 6 :: Int)])
  print (m3 // [((i, i), 0) | i <- [1 .. 3]])
  print (let a = listArray (0, 2) "abc" in (a // [(0, 'z')], a))
  print (accum (-) (listArray (0, 1) [10, 20]) [(0, 1), (1, 2), (0, 3) :: (Int, Int)])
  print (fmap (const True) (array (1, 2) [(1, undefined), (2, 'x')]) ! 1, fmap fromEnum (listArray (0, 1) "AB"))
  print (ixmap (0, 1) (\i -> 1 - i) (listArray (0, 1) "pq"), subArray ((1, 2), (2, 3)) m3)
  print (row 2 m3, diag m3, firstArray (listArray (0, 1) [(1, 'a'), (2, 'b')] :: Array Int (Int, Char)))
  print (show (listArray (0, 1) "ab"), read (show (listArray (0, 1) "ab")) == listArray (0, 1) "ab")
  print (listArray (0, 2) "ab" ! 0, listArray (0, 2) "ab" ! 1)
  print (array (1, 3) [(1, 'a'), (3, 'c')] ! 3, array (1, 2) [(1, 'a'), (1, 'b'), (2, 'c')] ! 2, (listArray (1, 2) "ab" // [(2, 'x'), (2, 'y')]) ! 1)
