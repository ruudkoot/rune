-- A type with Eq, Show and Num of its own, whose Read instance is an
-- orphan's (build-cache-issues.md, issue 26).
module N where

newtype N = N Integer

instance Eq N where
  N a == N b = a == b

instance Show N where
  show (N k) = "N" ++ show k

instance Num N where
  N a + N b = N (a + b)
  N a * N b = N (a * b)
  abs (N a) = N (abs a)
  signum (N a) = N (signum a)
  negate (N a) = N (negate a)
  fromInteger k = N (k * 10)
