module M (x, A.y, f, m, N.z, (+++), S, T, t, K, abs1, R(R)) where

import A (y)
import qualified N

x :: Int
x = 1

data R = R { f :: Int }

class K a where
  m :: a -> Int

instance K Bool where
  m _ = 0

(+++) :: Int -> Int -> Int
a +++ b = a + b

type S = Int

data T = T

t :: T
t = T

abs1 :: T -> Int
abs1 _ = 0
