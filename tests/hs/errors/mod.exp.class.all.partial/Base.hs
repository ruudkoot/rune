module Base (C(..)) where

class C a where
  c1 :: a -> Int
  c2 :: a -> Int

instance C Bool where
  c1 _ = 1
  c2 _ = 2
