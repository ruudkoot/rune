-- The context on b: T's derived Show needs Show F, which Main does not have.
module U where

data U a b = U a b

instance Show b => Show (U a b) where
  show (U _ b) = "U " ++ show b
