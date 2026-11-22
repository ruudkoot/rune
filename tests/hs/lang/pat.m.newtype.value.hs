-- rows: pat.m.newtype.bottom pat.m.newtype.coerce pat.irref.newtype pat.ex.data.lazy tr.case.k tr.case.l
-- Report 3.17.2: a newtype constructor's pattern matches as its argument does: on bottom it succeeds where the argument's
-- pattern is irrefutable; data D = D !Bool: (\ ~(D True) -> True) bottom is True; 3.17.3 (k), (l).
module Main (main) where

newtype N = N Int
newtype B = B Bool
data D = D !Bool

main :: IO ()
main = do
  print ((\(N 1) -> 2 :: Int) (N 1), (\(N _) -> 2 :: Int) undefined, (\(N x) -> 1 :: Int) undefined)
  print ((\ ~(D True) -> True) undefined)
  print (case N 3 of { N 3 -> "k"; _ -> "no" }, case 3 :: Int of { 3 -> "k"; _ -> "no" })
  print (case undefined of { N _ -> 1; _ -> 2 :: Int }, case undefined :: Int of { _ -> 1 :: Int })
