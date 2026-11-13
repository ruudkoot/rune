-- H2, H4 (E13, GHC's case, with Enum for its Show, which Haskell 98's Num holds): MyNum is a candidate of Main's
-- default that its Enum, absent, rules out (4.3.4).
module T where

newtype MyNum = MyNum Integer deriving (Eq, Show)

instance Num MyNum where
  MyNum a + MyNum b = MyNum (a + b)
  MyNum a * MyNum b = MyNum (a * b)
  abs = id
  signum = id
  fromInteger = MyNum
  negate = id
