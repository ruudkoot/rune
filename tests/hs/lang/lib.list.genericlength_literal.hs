-- rows: lib.list.generictake lib.list.genericdrop lib.list.genericsplitat lib.list.genericindex lib.list.genericreplicate
-- Report 17.9: the generic functions of List against the Report's own module, with erratum September 2008 (genericTake,
-- genericDrop and genericSplitAt take a negative count as 0), copied under new names, at Integer and Int.
module Main (main) where

import List
import Maybe (listToMaybe)

infix 5 \\.

elemIndex_r               :: Eq a => a -> [a] -> Maybe Int
elemIndex_r x             =  findIndex_r (x ==)

elemIndices_r             :: Eq a => a -> [a] -> [Int]
elemIndices_r x           =  findIndices_r (x ==)

find_r                    :: (a -> Bool) -> [a] -> Maybe a
find_r p                  =  listToMaybe . filter p

findIndex_r               :: (a -> Bool) -> [a] -> Maybe Int
findIndex_r p             =  listToMaybe . findIndices_r p

findIndices_r             :: (a -> Bool) -> [a] -> [Int]
findIndices_r p xs        =  [ i | (x,i) <- zip xs [0..], p x ]

nub_r                     :: Eq a => [a] -> [a]
nub_r                     =  nubBy_r (==)

nubBy_r                   :: (a -> a -> Bool) -> [a] -> [a]
nubBy_r eq []             =  []
nubBy_r eq (x:xs)         =  x : nubBy_r eq (filter (\y -> not (eq x y)) xs)

delete_r                  :: Eq a => a -> [a] -> [a]
delete_r                  =  deleteBy_r (==)

deleteBy_r                :: (a -> a -> Bool) -> a -> [a] -> [a]
deleteBy_r eq x []        = []
deleteBy_r eq x (y:ys)    = if x `eq` y then ys else y : deleteBy_r eq x ys

(\\.)                   :: Eq a => [a] -> [a] -> [a]
(\\.)                   =  foldl (flip delete_r)

deleteFirstsBy_r          :: (a -> a -> Bool) -> [a] -> [a] -> [a]
deleteFirstsBy_r eq       =  foldl (flip (deleteBy_r eq))

union_r                   :: Eq a => [a] -> [a] -> [a]
union_r                   =  unionBy_r (==)

unionBy_r                 :: (a -> a -> Bool) -> [a] -> [a] -> [a]
unionBy_r eq xs ys        =  xs ++ deleteFirstsBy_r eq (nubBy_r eq ys) xs

intersect_r               :: Eq a => [a] -> [a] -> [a]
intersect_r               =  intersectBy_r (==)

intersectBy_r             :: (a -> a -> Bool) -> [a] -> [a] -> [a]
intersectBy_r eq xs ys    =  [x | x <- xs, any (eq x) ys]

intersperse_r             :: a -> [a] -> [a]
intersperse_r sep []      =  []
intersperse_r sep [x]     =  [x]
intersperse_r sep (x:xs)  =  x : sep : intersperse_r sep xs

-- transpose_r is lazy in both rows and columns,
--       and works for non-rectangular 'matrices'
-- For example, transpose_r [[1,2],[3,4,5],[]]  =  [[1,3],[2,4],[5]]
-- Note that [h | (h:t) <- xss] is not the same as (map head xss)
--      because the former discards empty sublists inside xss
transpose_r                :: [[a]] -> [[a]]
transpose_r []             = []
transpose_r ([]     : xss) = transpose_r xss
transpose_r ((x:xs) : xss) = (x : [h | (h:t) <- xss]) :
                           transpose_r (xs : [t | (h:t) <- xss])

partition_r               :: (a -> Bool) -> [a] -> ([a],[a])
partition_r p xs          =  (filter p xs, filter (not . p) xs)

-- group_r splits its list argument into a list of lists of equal, adjacent
-- elements.  e.g.,
-- group_r "Mississippi" == ["M","i","ss","i","ss","i","pp","i"]
group_r                   :: Eq a => [a] -> [[a]]
group_r                   =  groupBy_r (==)

groupBy_r                 :: (a -> a -> Bool) -> [a] -> [[a]]
groupBy_r eq []           =  []
groupBy_r eq (x:xs)       =  (x:ys) : groupBy_r eq zs
                           where (ys,zs) = span (eq x) xs

-- inits_r xs returns the list of initial segments of xs, shortest first.
-- e.g., inits_r "abc" == ["","a","ab","abc"]
inits_r                   :: [a] -> [[a]]
inits_r []                =  [[]]
inits_r (x:xs)            =  [[]] ++ map (x:) (inits_r xs)

-- tails_r xs returns the list of all final segments of xs, longest first.
-- e.g., tails_r "abc" == ["abc", "bc", "c",""]
tails_r                   :: [a] -> [[a]]
tails_r []                =  [[]]
tails_r xxs@(_:xs)        =  xxs : tails_r xs

isPrefixOf_r               :: Eq a => [a] -> [a] -> Bool
isPrefixOf_r []     _      =  True
isPrefixOf_r _      []     =  False
isPrefixOf_r (x:xs) (y:ys) =  x == y && isPrefixOf_r xs ys

isSuffixOf_r              :: Eq a => [a] -> [a] -> Bool
isSuffixOf_r x y          =  reverse x `isPrefixOf_r` reverse y

mapAccumL_r               :: (a -> b -> (a, c)) -> a -> [b] -> (a, [c])
mapAccumL_r f s []        =  (s, [])
mapAccumL_r f s (x:xs)    =  (s'',y:ys)
                           where (s', y ) = f s x
                                 (s'',ys) = mapAccumL_r f s' xs

mapAccumR_r               :: (a -> b -> (a, c)) -> a -> [b] -> (a, [c])
mapAccumR_r f s []        =  (s, [])
mapAccumR_r f s (x:xs)    =  (s'', y:ys)
                           where (s'',y ) = f s' x
                                 (s', ys) = mapAccumR_r f s xs

unfoldr_r                 :: (b -> Maybe (a,b)) -> b -> [a]
unfoldr_r f b             = case f b of
                                Nothing    -> []
                                Just (a,b) -> a : unfoldr_r f b

sort_r                    :: (Ord a) => [a] -> [a]
sort_r                    =  sortBy_r compare

sortBy_r                  :: (a -> a -> Ordering) -> [a] -> [a]
sortBy_r cmp              =  foldr (insertBy_r cmp) []

insert_r                  :: (Ord a) => a -> [a] -> [a]
insert_r                  = insertBy_r compare

insertBy_r                :: (a -> a -> Ordering) -> a -> [a] -> [a]
insertBy_r cmp x []       =  [x]
insertBy_r cmp x ys@(y:ys')
                        =  case cmp x y of
                                GT -> y : insertBy_r cmp x ys'
                                _  -> x : ys

maximumBy_r               :: (a -> a -> Ordering) -> [a] -> a
maximumBy_r cmp []        =  error "List.maximumBy_r: empty list"
maximumBy_r cmp xs        =  foldl1 max xs
                        where
                           max x y = case cmp x y of
                                        GT -> x
                                        _  -> y

minimumBy_r               :: (a -> a -> Ordering) -> [a] -> a
minimumBy_r cmp []        =  error "List.minimumBy_r: empty list"
minimumBy_r cmp xs        =  foldl1 min xs
                        where
                           min x y = case cmp x y of
                                        GT -> y
                                        _  -> x

genericLength_r           :: (Integral a) => [b] -> a
genericLength_r []        =  0
genericLength_r (x:xs)    =  1 + genericLength_r xs

genericTake_r             :: (Integral a) => a -> [b] -> [b]
genericTake_r n _ | n <= 0 = []
genericTake_r _ []        =  []
genericTake_r n (x:xs)    =  x : genericTake_r (n-1) xs

genericDrop_r             :: (Integral a) => a -> [b] -> [b]
genericDrop_r n xs | n <= 0 = xs
genericDrop_r _ []        =  []
genericDrop_r n (_:xs)    =  genericDrop_r (n-1) xs

genericSplitAt_r          :: (Integral a) => a -> [b] -> ([b],[b])
genericSplitAt_r n xs | n <= 0 =  ([],xs)
genericSplitAt_r _ []     =  ([],[])
genericSplitAt_r n (x:xs) =  (x:xs',xs'') where
    (xs',xs'') = genericSplitAt_r (n-1) xs

genericIndex_r            :: (Integral a) => [b] -> a -> b
genericIndex_r (x:_)  0   =  x
genericIndex_r (_:xs) n
        | n > 0         =  genericIndex_r xs (n-1)
        | otherwise     =  error "List.genericIndex_r: negative argument"
genericIndex_r _ _        =  error "List.genericIndex_r: index too large"

genericReplicate_r        :: (Integral a) => a -> b -> [b]
genericReplicate_r n x    =  genericTake_r n (repeat x)

zip4_r                    :: [a] -> [b] -> [c] -> [d] -> [(a,b,c,d)]
zip4_r                    =  zipWith4_r (,,,)

zip5_r                    :: [a] -> [b] -> [c] -> [d] -> [e] -> [(a,b,c,d,e)]
zip5_r                    =  zipWith5_r (,,,,)

zip6_r                    :: [a] -> [b] -> [c] -> [d] -> [e] -> [f] ->
                              [(a,b,c,d,e,f)]
zip6_r                    =  zipWith6_r (,,,,,)

zip7_r                    :: [a] -> [b] -> [c] -> [d] -> [e] -> [f] ->
                              [g] -> [(a,b,c,d,e,f,g)]
zip7_r                    =  zipWith7_r (,,,,,,)

zipWith4_r                :: (a->b->c->d->e) -> [a]->[b]->[c]->[d]->[e]
zipWith4_r z (a:as) (b:bs) (c:cs) (d:ds)
                        =  z a b c d : zipWith4_r z as bs cs ds
zipWith4_r _ _ _ _ _      =  []

zipWith5_r                :: (a->b->c->d->e->f) ->
                           [a]->[b]->[c]->[d]->[e]->[f]
zipWith5_r z (a:as) (b:bs) (c:cs) (d:ds) (e:es)
                        =  z a b c d e : zipWith5_r z as bs cs ds es
zipWith5_r _ _ _ _ _ _    =  []

zipWith6_r                :: (a->b->c->d->e->f->g) ->
                           [a]->[b]->[c]->[d]->[e]->[f]->[g]
zipWith6_r z (a:as) (b:bs) (c:cs) (d:ds) (e:es) (f:fs)
                        =  z a b c d e f : zipWith6_r z as bs cs ds es fs
zipWith6_r _ _ _ _ _ _ _  =  []

zipWith7_r                :: (a->b->c->d->e->f->g->h) ->
                           [a]->[b]->[c]->[d]->[e]->[f]->[g]->[h]
zipWith7_r z (a:as) (b:bs) (c:cs) (d:ds) (e:es) (f:fs) (g:gs)
                   =  z a b c d e f g : zipWith7_r z as bs cs ds es fs gs
zipWith7_r _ _ _ _ _ _ _ _ = []

unzip4_r                  :: [(a,b,c,d)] -> ([a],[b],[c],[d])
unzip4_r                  =  foldr (\(a,b,c,d) ~(as,bs,cs,ds) ->
                                        (a:as,b:bs,c:cs,d:ds))
                                 ([],[],[],[])

unzip5_r                  :: [(a,b,c,d,e)] -> ([a],[b],[c],[d],[e])
unzip5_r                  =  foldr (\(a,b,c,d,e) ~(as,bs,cs,ds,es) ->
                                        (a:as,b:bs,c:cs,d:ds,e:es))
                                 ([],[],[],[],[])

unzip6_r                  :: [(a,b,c,d,e,f)] -> ([a],[b],[c],[d],[e],[f])
unzip6_r                  =  foldr (\(a,b,c,d,e,f) ~(as,bs,cs,ds,es,fs) ->
                                        (a:as,b:bs,c:cs,d:ds,e:es,f:fs))
                                 ([],[],[],[],[],[])

unzip7_r          :: [(a,b,c,d,e,f,g)] -> ([a],[b],[c],[d],[e],[f],[g])
unzip7_r          =  foldr (\(a,b,c,d,e,f,g) ~(as,bs,cs,ds,es,fs,gs) ->
                                (a:as,b:bs,c:cs,d:ds,e:es,f:fs,g:gs))
                         ([],[],[],[],[],[],[])

xss :: [[Int]]
xss = [[], [1], [1, 1], [3, 1, 2], [2, 2, 1, 3, 3, 1], [5, 4, 3, 2, 1], [1, 2, 3, 4, 5, 6], [0, -1, 1, -1, 0]]

ns :: [Int]
ns = [-1 .. 6]

ps :: [Int -> Bool]
ps = [even, (> 2), const False, (== 1)]

mod3, absEq :: Int -> Int -> Bool
mod3 x y = x `mod` 3 == y `mod` 3
absEq x y = abs x == abs y

main :: IO ()
main = do
  print (and [genericLength xs == (genericLength_r xs :: Integer) && genericLength xs == (genericLength_r xs :: Int) | xs <- xss])
  print (and [genericTake n xs == genericTake_r n xs && genericDrop n xs == genericDrop_r n xs && genericSplitAt n xs == genericSplitAt_r n xs | n <- [-2 .. 7 :: Integer], xs <- xss])
  print (and [genericTake n xs == genericTake_r n xs && genericDrop n xs == genericDrop_r n xs | n <- [-1, 0, 3 :: Int], xs <- xss])
  print (and [genericIndex xs n == genericIndex_r xs n | xs <- xss, n <- [0 .. genericLength xs - 1 :: Integer]])
  print (and [genericReplicate n 'x' == genericReplicate_r n 'x' | n <- [-1 .. 4 :: Integer]], genericReplicate (2 :: Int) True == genericReplicate_r 2 True)
  print (genericTake (3 :: Integer) [1 :: Int ..] == genericTake_r 3 [1 ..], take 2 (genericDrop (5 :: Integer) [1 :: Int ..]) == take 2 (genericDrop_r 5 [1 ..]), take 2 (fst (genericSplitAt (4 :: Integer) [1 :: Int ..])) == take 2 (fst (genericSplitAt_r 4 [1 ..])), genericIndex [1 :: Int ..] (10 :: Integer) == genericIndex_r [1 ..] 10)
