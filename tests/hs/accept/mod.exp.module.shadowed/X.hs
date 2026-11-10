module X (module Q, out) where

import N as Q
import R

out :: Int
out = Q.x + R.x
