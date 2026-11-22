module A (f, n) where

import B (g)

f 0 = []
f k = 'a' : g (k - 1)

n = 2
x = n + (1 :: Int)
