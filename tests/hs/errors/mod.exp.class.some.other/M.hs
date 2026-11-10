module M (K, L(l1), V(..), mk) where

class K a where
  k :: a -> Int

class L a where
  l1 :: a -> Int
  l2 :: a -> Int

class V a where
  v1 :: a -> Int
  v2 :: a -> Int

data T = T

instance K T where
  k _ = 1
instance L T where
  l1 _ = 2
  l2 _ = 3
instance V T where
  v1 _ = 4
  v2 _ = 5

mk :: T
mk = T
