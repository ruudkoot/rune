module Base (C(..)) where

class C a where
  c :: a -> Int

instance C Bool where
  c _ = 1
