module N where

newtype N = N Integer

instance Eq N where
  N a == N b = a == b

instance Show N where
  show (N k) = "N" ++ show k
