module M where

x :: Int
x = 1

data T = T
data T2 = C Int deriving Eq

class K a where
  m :: a -> Int

instance K T where
  m _ = 0
