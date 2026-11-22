module A (Ta(..), fa, ca) where

import B

data Ta = Ta Int | Tb Tb

fa :: Int -> Int
fa 0 = 0
fa n = fb (n - 1)

class Ca a where
  ca :: a -> Int

instance Ca Ta where
  ca (Ta n) = n
  ca (Tb t) = cb t
