module Array (
    module Ix, Array, array, listArray, (!), bounds, indices, elems, assocs,
    accumArray, (//), accum, ixmap
  ) where
import Ix
import Data.List (foldl')
infixl 9 !, //
data Array a b = MkArray (a,a) (a -> b)
array :: (Ix a) => (a,a) -> [(a,b)] -> Array a b
array b ivs
  | any (not . inRange b . fst) ivs = error "Array.array: out-of-range array association"
  | otherwise = MkArray b (\j -> case lookup j ivs of { Just v -> v; Nothing -> error "Array.!: undefined array element" })
listArray :: (Ix a) => (a,a) -> [b] -> Array a b
listArray b vs = array b (zip (range b) vs)
(!) :: (Ix a) => Array a b -> a -> b
(!) (MkArray _ f) = f
bounds :: (Ix a) => Array a b -> (a,a)
bounds (MkArray b _) = b
indices :: (Ix a) => Array a b -> [a]
indices = range . bounds
elems :: (Ix a) => Array a b -> [b]
elems a = [a ! i | i <- indices a]
assocs :: (Ix a) => Array a b -> [(a,b)]
assocs a = [(i, a ! i) | i <- indices a]
(//) :: (Ix a) => Array a b -> [(a,b)] -> Array a b
a // new = array (bounds a) (old ++ new) where
  old = [(i, a ! i) | i <- indices a, i `notElem` map fst new]
accum :: (Ix a) => (b -> c -> b) -> Array a b -> [(a,c)] -> Array a b
accum f = foldl (\a (i,v) -> a // [(i, f (a ! i) v)])
accumArray :: (Ix a) => (b -> c -> b) -> b -> (a,a) -> [(a,c)] -> Array a b
accumArray f z b = accum f (array b [(i,z) | i <- range b])
ixmap :: (Ix a, Ix b) => (a,a) -> (a -> b) -> Array b c -> Array a c
ixmap b f a = array b [(i, a ! f i) | i <- range b]
instance (Ix a) => Functor (Array a) where
  fmap fn (MkArray b f) = MkArray b (fn . f)
instance (Ix a, Eq b) => Eq (Array a b) where
  a == a' = assocs a == assocs a'
instance (Ix a, Ord b) => Ord (Array a b) where
  a <= a' = assocs a <= assocs a'
instance (Ix a, Show a, Show b) => Show (Array a b) where
  showsPrec p a = showParen (p > 9) (showString "array " . showsPrec 10 (bounds a) . showChar ' ' . showsPrec 10 (assocs a))
