-- The instance in the type's own module, I0's gone.
module T where

newtype MyNum = MyNum Integer deriving (Eq, Show)

instance Num MyNum where
  MyNum a + MyNum b = MyNum (a + b)
  MyNum a * MyNum b = MyNum (a * b)
  abs = id
  signum = id
  fromInteger = MyNum
  negate = id

instance Enum MyNum where
  toEnum = MyNum . toInteger
  fromEnum (MyNum n) = fromInteger n
  succ (MyNum n) = MyNum (n + 10)
