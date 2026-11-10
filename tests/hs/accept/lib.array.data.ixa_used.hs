-- rows: lib.r.array.exportsix lib.r.array.functor.context R49 R152
-- Report 16: Array a b at Ix a, of kind * -> * -> *; Array exports module Ix, so range needs no import of Ix; and
-- Functor (Array a) has the context (Ix a), as the code says (readings.md R152).
module Main (main) where

import Array

data K f = K (f Int Char)

k :: K Array
k = K (listArray (0, 0) "x")

r :: [Int]
r = range (1, 2)

g :: (Ix a) => Array a Int -> Array a Int
g = fmap (+ 1)

h :: (Ix a, Ix b) => Array (a, b) Char -> (Bool, Int)
h x = (inRange (bounds x) (fst (bounds x)), rangeSize (bounds x))

main :: IO ()
main = return ()
