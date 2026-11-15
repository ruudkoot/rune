-- H5 again: U's instance's context moves from one variable to the other, the classes it names the same.
module U where

data U a b = U a b

instance Show a => Show (U a b) where
  show (U a _) = "U " ++ show a
