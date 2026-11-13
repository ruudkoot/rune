-- An orphan instance two imports from Main, on no import list: MyNum is the default now.
module I0 where

import T

instance Enum MyNum where
  toEnum = MyNum . toInteger
  fromEnum (MyNum n) = fromInteger n
  succ (MyNum n) = MyNum (n + 10)
