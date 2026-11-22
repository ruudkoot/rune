-- rows: der.cond.class.eq der.cond.class.ord der.cond.class.enum der.cond.class.bounded der.cond.class.show der.cond.class.read der.cond.constituent.mutual der.cond.bounded.enum der.cond.bounded.single der.newtype.asdata der.deriving.empty.accept der.deriving.single der.deriving.multi der.inst.form der.inst.context.smallest der.inst.context.fixpoint der.inst.context.nested
-- Report 10: a deriving clause makes each of Eq, Ord, Enum, Bounded, Show and Read usable with no instance declaration,
-- for enumerations, single constructors, newtypes and mutually recursive types, its context the least the uses need.
module Main (main) where

data A = A deriving Eq
data B = B deriving (Eq, Ord)
data C = C1 | C2 | C3 deriving (Enum, Bounded, Show, Read)
data S = S Bool Char deriving Bounded
data X = X deriving ()
data P = P Int deriving (Eq, Ord, Show, Read)
data M1 = M1 | M1M M2 deriving Eq
data M2 = M2 M1 deriving Eq
newtype N = N Int deriving (Eq, Ord, Show, Read)
data T a b = T a deriving Eq
data R a = RN | R (Q a) deriving Eq
data Q a = Q (R a) a deriving Eq
data U a = UN | UC a (U [a]) deriving Eq

uses :: (Bool, Bool, [C], (C, C), S, String, C, Bool, Bool, Bool, Bool, Bool)
uses = (A == A, B < B, [C1 ..], (minBound, maxBound), maxBound, show C2, read "C3", P 1 < P 2, M1M (M2 M1) == M1, N 1 == N 1,
        T 1 == (T 1 :: T Int (Int -> Int)), UC 1 UN == UC (1 :: Int) UN)

main :: IO ()
main = return ()
