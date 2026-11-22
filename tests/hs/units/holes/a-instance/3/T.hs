-- T's Show instance its own now, I's gone.
module T (T(..)) where

data T = T

instance Show T where
  show _ = "from T"
