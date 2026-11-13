module A (x, f) where

import B

x = 1

f n = if n == 0 then 0 else g (n - 1)
