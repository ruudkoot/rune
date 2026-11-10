module M (C(d)) where

class C a where
  c :: a -> Int

class D a where
  d :: a -> Int
