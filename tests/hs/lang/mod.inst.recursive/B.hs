module B (U(..)) where

import A (T(..))

data U = U Int

instance Show U where
  show (U n) = "U" ++ show n

instance Show T where
  show (T n) = "T" ++ show n
