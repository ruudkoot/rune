-- A type whose Num instance is an orphan's (build-cache-issues.md, issue 26).
module N where

newtype N = N Integer

instance Eq N where
  N a == N b = a == b

instance Show N where
  show (N k) = "N" ++ show k
