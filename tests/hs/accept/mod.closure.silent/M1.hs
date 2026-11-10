module M1 (x, K(k)) where

data T = T

class K a where
  k :: a -> Int

instance K T where
  k _ = 1

x :: T
x = T
