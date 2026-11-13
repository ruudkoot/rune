-- U's instance needs Eq a: T's derived Show needs it too, and Main, with no Eq N, is refused.
module U where

data U a = U a

instance (Show a, Eq a) => Show (U a) where
  show (U a) = "U " ++ show a
