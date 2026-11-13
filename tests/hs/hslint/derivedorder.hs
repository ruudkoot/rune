-- HsLint's replay of a derived instance's dictionaries (the roadmap's M16; GHC's deriving/should_compile/drv003, of
-- tests/hs/rhc-corpus.txt): the checker's fixpoint gives Eq (T a b) the context Eq a, Ping b, Eq b, Ping a, and
-- HsLint's least context is the same four in another order. The order is the checker's to choose, so replay pairs
-- the instance's dictionaries with the checker's context, held to HsLint's as the same predicates.
module Main (main) where

data T a b
  = C1 (Foo a) (Bar b)
  | C2 Int (T b a)
  | C3 (T a a)
  deriving Eq

data Foo a = MkFoo Double a
instance Eq a => Eq (Foo a) where
  MkFoo x a == MkFoo y b = x == y && a == b

data Bar a = MkBar Int Int
instance Ping b => Eq (Bar b) where
  MkBar i j == MkBar k l = i == k && j == l

class Ping a where
  ping :: a -> Int

instance Ping Char where
  ping _ = 1

main :: IO ()
main = print (C1 (MkFoo 1 'a') (MkBar 1 2) == C2 3 (C3 (C1 (MkFoo 2 'b') (MkBar 3 4))), ping 'c')
