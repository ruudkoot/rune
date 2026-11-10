-- Module Array, section 16.4 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module  Array ( 
    module Ix,  -- export all of Ix 
    Array, array, listArray, (!), bounds, indices, elems, assocs, 
    accumArray, (//), accum, ixmap ) where

import Ix
import List( (\\) )
import PreludeBuiltin (Arr, arr_new, arr_read, arr_get, arr_set, unsafe_perform_io)  -- (rhc's)

infixl 9  !, //

-- An array is its bounds and its elements, each at its index's place, so
-- that (!) is a read in constant time, as 16 expects ("rapid access to the
-- components"): the meaning of each function is the Report's (overlay
-- ov.array.representation).
data (Ix a) => Array a b = MkArray (a,a) (Arr (Element b)) deriving ()

-- an element: no association gave it, one did, or several did
data Element b = Undefined | Defined b | Multiple

array       :: (Ix a) => (a,a) -> [(a,b)] -> Array a b
array b ivs =
    if and [inRange b i | (i,_) <- ivs]
        then MkArray b (place b ivs)
        else error "Array.array: out-of-range array association"

-- the elements of an array, put in place the first time one is read
place       :: (Ix a) => (a,a) -> [(a,b)] -> Arr (Element b)
place b ivs =  unsafe_perform_io (do
                   elems <- arr_new (rangeSize b) Undefined
                   mapM_ (put elems) ivs
                   return elems)
  where put elems (i,v) = do
          let k = index b i
          e <- arr_read elems k
          arr_set elems k (case e of Undefined -> Defined v
                                     _         -> Multiple)

listArray             :: (Ix a) => (a,a) -> [b] -> Array a b
listArray b vs        =  array b (zipWith (\ a b -> (a,b)) (range b) vs)

(!)                   :: (Ix a) => Array a b -> a -> b
(!) (MkArray b elems) i =
                         case arr_get elems (index b i) of
                           Defined v -> v
                           Undefined -> error "Array.!: undefined array element"
                           Multiple  -> error "Array.!: multiply defined array element"

bounds                :: (Ix a) => Array a b -> (a,a)
bounds (MkArray b _)  =  b

indices               :: (Ix a) => Array a b -> [a]
indices               =  range . bounds

elems                 :: (Ix a) => Array a b -> [b]
elems a               =  [a!i | i <- indices a]

assocs                :: (Ix a) => Array a b -> [(a,b)]
assocs a              =  [(i, a!i) | i <- indices a]

(//)                  :: (Ix a) => Array a b -> [(a,b)] -> Array a b
a // new_ivs          = array (bounds a) (old_ivs ++ new_ivs)
                      where
                  	old_ivs = [(i,a!i) | i <- indices a,
                                             i `notElem` new_is]
                  	new_is  = [i | (i,_) <- new_ivs]

accum                 :: (Ix a) => (b -> c -> b) -> Array a b -> [(a,c)]
                                   -> Array a b
accum f               =  foldl (\a (i,v) -> a // [(i,f (a!i) v)])

accumArray            :: (Ix a) => (b -> c -> b) -> b -> (a,a) -> [(a,c)]
                                   -> Array a b
accumArray f z b      =  accum f (array b [(i,z) | i <- range b])

ixmap                 :: (Ix a, Ix b) => (a,a) -> (a -> b) -> Array b c
                                         -> Array a c
ixmap b f a           = array b [(i, a ! f i) | i <- range b]

instance  (Ix a)          => Functor (Array a) where
    fmap fn a@(MkArray b _) = array b [(i, fn (a!i)) | i <- range b]

instance  (Ix a, Eq b)  => Eq (Array a b)  where
    a == a' =  assocs a == assocs a'

instance  (Ix a, Ord b) => Ord (Array a b)  where
    a <= a' =  assocs a <= assocs a'

instance  (Ix a, Show a, Show b) => Show (Array a b)  where
    showsPrec p a = showParen (p > arrPrec) (
                    showString "array " .
                    showsPrec (arrPrec+1) (bounds a) . showChar ' ' .
                    showsPrec (arrPrec+1) (assocs a)                  )

instance  (Ix a, Read a, Read b) => Read (Array a b)  where
    readsPrec p = readParen (p > arrPrec)
           (\r -> [ (array b as, u) 
                  | ("array",s) <- lex r,
                    (b,t)       <- readsPrec (arrPrec+1) s,
                    (as,u)      <- readsPrec (arrPrec+1) t ])

-- Precedence of the 'array' function is that of application itself
arrPrec = 10
