-- rows: pre.class.eq pre.class.eq.eqeq pre.class.eq.slasheq
-- Report 8: class Eq: x /= y = not (x == y) and x == y = not (x /= y), each the default where the other is defined, and a
-- method defined overrides its default.
module Main (main) where

data A = A Int
instance Eq A where
  A x == A y = x == y

data B = B Int
instance Eq B where
  B x /= B y = x /= y

data C = C
instance Eq C where
  _ == _ = True
  _ /= _ = True

main :: IO ()
main = print [A 1 /= A 2, A 1 /= A 1, B 1 == B 1, B 1 == B 2, C == C, C /= C]
