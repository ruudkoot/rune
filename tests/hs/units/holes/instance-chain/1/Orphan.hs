-- N's Num instance, in scope where a chain of imports leads here (5.4).
module Orphan where

import N

instance Num N where
  N a + N b = N (a + b)
  N a * N b = N (a * b)
  abs (N a) = N (abs a)
  signum (N a) = N (signum a)
  negate (N a) = N (negate a)
  fromInteger k = N (k * 10)
