-- rows: lib.array.listarray lib.array.bang lib.array.bounds lib.array.indices lib.array.elems lib.array.assocs lib.array.slashslash lib.array.accum lib.array.accumarray lib.array.ixmap lib.array.arrprec.def lib.array.inst.functorarraya lib.array.inst.eqarrayab lib.array.inst.ordarrayab lib.array.inst.showarrayab lib.array.inst.readarrayab lib.array.fixity.9bangcslashslash
-- Report 16.4: the functions of Array against the Report's own module copied over a type of its own (MkArray and its
-- function), each on samples by bounds and assocs; the instances by the code: Eq and Ord by assocs (two empty
-- arrays are equal whatever their bounds), Show and Read at arrPrec 10; infixl 9 ! and //.
module Main (main) where

import Array
import List ((\\))

infixl 9  !., //.

data Arr a b = MkArr (a,a) (a -> b)

array_r       :: (Ix a) => (a,a) -> [(a,b)] -> Arr a b
array_r b ivs =
    if and [inRange b i | (i,_) <- ivs]
        then MkArr b
                     (\j -> case [v | (i,v) <- ivs, i == j] of
                            [v]   -> v
                            []    -> error "Array.!: \
                                           \undefined array_r element"
                            _     -> error "Array.!: \
                                           \multiply defined array_r element")
        else error "Array.array_r: out-of-range array_r association"

listArray_r             :: (Ix a) => (a,a) -> [b] -> Arr a b
listArray_r b vs        =  array_r b (zipWith (\ a b -> (a,b)) (range b) vs)

(!.)                   :: (Ix a) => Arr a b -> a -> b
(!.) (MkArr _ f)     =  f

bounds_r                :: (Ix a) => Arr a b -> (a,a)
bounds_r (MkArr b _)  =  b

indices_r               :: (Ix a) => Arr a b -> [a]
indices_r               =  range . bounds_r

elems_r                 :: (Ix a) => Arr a b -> [b]
elems_r a               =  [a!.i | i <- indices_r a]

assocs_r                :: (Ix a) => Arr a b -> [(a,b)]
assocs_r a              =  [(i, a!.i) | i <- indices_r a]

(//.)                  :: (Ix a) => Arr a b -> [(a,b)] -> Arr a b
a //. new_ivs          = array_r (bounds_r a) (old_ivs ++ new_ivs)
                      where
                          old_ivs = [(i,a!.i) | i <- indices_r a,
                                             i `notElem` new_is]
                          new_is  = [i | (i,_) <- new_ivs]

accum_r                 :: (Ix a) => (b -> c -> b) -> Arr a b -> [(a,c)]
                                   -> Arr a b
accum_r f               =  foldl (\a (i,v) -> a //. [(i,f (a!.i) v)])

accumArray_r            :: (Ix a) => (b -> c -> b) -> b -> (a,a) -> [(a,c)]
                                   -> Arr a b
accumArray_r f z b      =  accum_r f (array_r b [(i,z) | i <- range b])

ixmap_r                 :: (Ix a, Ix b) => (a,a) -> (a -> b) -> Arr b c
                                         -> Arr a c
ixmap_r b f a           = array_r b [(i, a !. f i) | i <- range b]

fmapA :: (Ix a) => (b -> c) -> Arr a b -> Arr a c
fmapA fn (MkArr b f) = MkArr b (fn . f)


eqA :: (Ix a, Eq b) => Array a b -> Arr a b -> Bool
eqA a r = bounds a == bounds_r r && assocs a == assocs_r r

arrPrec' :: Int
arrPrec' = 10

ivs :: [(Int, Char)]
ivs = [(3, 'c'), (1, 'a'), (2, 'b')]

m :: Array (Int, Int) Int
m = listArray ((1, 1), (3, 3)) [1 ..]

mr :: Arr (Int, Int) Int
mr = listArray_r ((1, 1), (3, 3)) [1 ..]

main :: IO ()
main = do
  print (eqA (array (1, 3) ivs) (array_r (1, 3) ivs), eqA (array (1, 0) ivs') (array_r (1, 0) ivs'), eqA (listArray (0, 4) "hello") (listArray_r (0, 4) "hello"))
  print (eqA m mr, [m ! i == mr !. i | i <- range ((1, 1), (3, 3))], indices m == indices_r mr, elems m == elems_r mr)
  print (eqA (m // [((2, 2), 0), ((1, 3), 9)]) (mr //. [((2, 2), 0), ((1, 3), 9)]), eqA (accum (+) m [((1, 1), 10), ((1, 1), 5)]) (accum_r (+) mr [((1, 1), 10), ((1, 1), 5)]))
  print (eqA (accumArray (+) 0 (0, 3) [(1, 1), (3, 2), (1, 4)]) (accumArray_r (+) 0 (0, 3) [(1, 1), (3, 2), (1, 4 :: Int)]), eqA (accumArray (flip (:)) "" (0, 2) [(0, 'a'), (2, 'b'), (0, 'c')]) (accumArray_r (flip (:)) "" (0, 2) [(0, 'a'), (2, 'b'), (0, 'c')]))
  print (eqA (ixmap (1, 3) (\i -> (i, i)) m) (ixmap_r (1, 3) (\i -> (i, i)) mr), eqA (fmap (* 2) m) (fmapA (* 2) mr))
  print (array (1, 3) ivs == listArray (1, 3) "abc", array (1, 3) ivs /= listArray (1, 3) "abd", listArray (1, 0) [] == (listArray (5, 4) [] :: Array Int Int))
  print (compare (listArray (0, 1) "ab") (listArray (0, 1) "ac"), listArray (0, 1) "b" <= listArray (0, 1) "ab", max (listArray (0, 0) "z") (listArray (1, 1) "a"))
  print (showsPrec arrPrec' (listArray (0, 1) "ab") "", showsPrec (arrPrec' + 1) (listArray (0, 1) "ab") "", show (Just (listArray (1, 1) [True])))
  print (read "array (1,2) [(1,'x'),(2,'y')]" == listArray (1, 2) "xy", read " ( array (0,0) [(0,5)] ) " == (listArray (0, 0) [5] :: Array Int Int))
  print ((readsPrec 11 "array (0,0) [(0,1)]" :: [(Array Int Int, String)]), map fst (readsPrec 10 "array (0,0) [(0,1)] x" :: [(Array Int Int, String)]))
  print (listArray (0, 2) "abc" // [(1, 'z')] ! 1, (listArray (0, 2) "abc" ! 2 :: Char))
  where ivs' = [] :: [(Int, Char)]
