-- rows: pre.class.ord pre.class.ord.compare pre.class.ord.lt pre.class.ord.lteq pre.class.ord.gteq pre.class.ord.gt pre.class.ord.max pre.class.ord.min
-- Report 8: class Ord's defaults: compare from == and <=, the comparisons from compare, max and min from <=; every method
-- defined overrides its default.
module Main (main) where

data A = A Int deriving Eq
instance Ord A where
  compare (A x) (A y) = compare x y

data B = B Int deriving Eq
instance Ord B where
  B x <= B y = x <= y

data C = C Int deriving (Eq, Show)
instance Ord C where
  compare _ _ = GT
  _ < _ = True
  _ <= _ = False
  _ >= _ = False
  _ > _ = True
  max _ _ = C 100
  min _ _ = C (-100)

main :: IO ()
main = do
  print [A 1 < A 2, A 1 <= A 1, A 2 > A 1, A 1 >= A 2]
  print (compare (A 1) (A 2), max (A 1) (A 2) == A 2, min (A 1) (A 2) == A 1)
  print [B 1 < B 2, B 2 <= B 1, B 2 > B 1, B 1 >= B 1]
  print (compare (B 1) (B 2), compare (B 2) (B 2), compare (B 3) (B 2))
  print [C 1 < C 1, C 1 <= C 1, C 1 >= C 1, C 1 > C 1]
  print (compare (C 1) (C 1), max (C 1) (C 2), min (C 1) (C 2))
