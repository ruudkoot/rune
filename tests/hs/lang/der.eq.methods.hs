-- rows: der.ord.methods der.ord.lexicographic der.ord.conorder der.ord.example.bool der.ord.fields.lexi der.ord.compare.eq der.ord.maxmin.pair der.eq.lefttoright der.eq.example.1 der.ord.lefttoright der.eq.diffcon der.ord.conorder.fields
-- Report 10.1: derived == and compare go constructor first, then fields left to right, stopping at the first difference;
-- constructors are ordered as declared; the Report's examples.
module Main (main) where

data T = A Int | B deriving (Eq, Ord, Show)
data P = P Int Int deriving (Eq, Ord, Show)

main :: IO ()
main = do
  print (A 1 == A 1, A 1 /= B, A 9 < B, B > A 0, compare (A 1) (A 2))
  print (P 1 9 < P 2 0, P 1 2 <= P 1 2, P 2 0 >= P 1 9, max (P 1 2) (P 1 3), min (P 1 2) (P 1 3))
  print (True > False, compare (P 1 1) (P 1 1), A 1 == B, P 1 undefined == P 2 undefined)
  print ((1 :: Int, undefined :: Int) < (2, undefined), A undefined == B, compare (A undefined) B)
